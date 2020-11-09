#!/usr/bin/env bash
# Modifications copyright (C) 2020 Peng Yi
# Adding wav subsamppling, MFCC and CMVN feature computation, and i-vectors
# extraction steps to prepare inputs of a new wav file for the DNN 
# accoustic model. This script intends to support building pipelines in 
# a web application.

# Copyright 2019 Junbo Zhang
# Apache 2.0

# This script shows how to calculate Goodness of Pronunciation (GOP) and
# extract phone-level pronunciation feature for mispronunciations detection
# tasks. Read ../README.md or the following paper for details:
#
# "Hu et al., Improved mispronunciation detection with deep neural network
# trained acoustic models and transfer learning based logistic regression
# classifiers, 2015."


# You might not want to do this for interactive shells.
set -e

# Global configurations
stage=0
nj=1
cmd="run.pl"

. ./path.sh

if [ $# -ne 2 ]; then
   echo "Usage: $0 <wav-file> <transcript-file>"
   echo "e.g.: $0 web/2020-11-08-user1.wav web/2020-11-08-user1.txt"
   exit 1;
fi

for f in $1 $2; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1;
done

# This script assumes the nnt3 model and i-vector extractor exist.
# Pre-trained model can be downloaded at http://kaldi-asr.org/models/m13
librispeech_eg=../../librispeech/s5
model=$librispeech_eg/exp/chain_cleaned/tdnn_1d_sp
lang=$librispeech_eg/data/lang_test_tgsmall
ivector_extractor=$librispeech_eg/exp/nnet3_cleaned/extractor

# prepare per-utterrance directories
wav_id=$(basename -s .wav $1 | sed s/-/_/g)
ivectors=web/$wav_id/ivectors
data=web/$wav_id/data
exp=web/$wav_id/exp
mkdir -p $ivectors $data $exp

if [ $stage -le 0 ]; then
  # subsmaple wav to 16kHz
  sox $1 -r 16000 web/$wav_id/$wav_id.wav
fi

if [ $stage -le 1 ]; then
  # format the data as Kaldi data directories
  echo "$wav_id web/$wav_id/$wav_id.wav" > $data/wav.scp
  echo "$wav_id $(cat $2)" > $data/text
  echo "$wav_id $wav_id" > $data/utt2spk
  echo "$wav_id $wav_id" > $data/spk2utt
fi

if [ $stage -le 2 ]; then
  # extract MFCC and CMVN features
  steps/make_mfcc.sh --nj $nj --mfcc-config $librispeech_eg/conf/mfcc_hires.conf \
    --cmd $cmd $data
  steps/compute_cmvn_stats.sh $data
fi

if [ $stage -le 3 ]; then
  # extract i-vectors
  steps/online/nnet2/extract_ivectors_online.sh --cmd $cmd --nj $nj \
    $data $ivector_extractor $ivectors
fi

if [ $stage -le 4 ]; then
  # compute Log-likelihoods
  steps/nnet3/compute_output.sh --cmd "$cmd" --nj $nj \
    --online-ivector-dir $ivectors $data $model $exp/probs_lpp_lpr
fi

if [ $stage -le 5 ]; then
  # generate Alignment
  steps/nnet3/align.sh --cmd "$cmd" --nj $nj --use_gpu false \
    --online_ivector_dir $ivectors $data $lang $model $exp/gop
fi

if [ $stage -le 6 ]; then
  # make a map which converts phones to "pure-phones"
  # "pure-phone" means the phone whose stress and pos-in-word markers are ignored
  # eg. AE1_B --> AE, EH2_S --> EH, SIL --> SIL
  local/remove_phone_markers.pl $lang/phones.txt $exp/gop/phones-pure.txt \
    $exp/gop/phone-to-pure-phone.int

  # Convert transition-id to pure-phone id
  $cmd JOB=1:$nj $exp/gop/log/ali_to_phones.JOB.log \
    ali-to-phones --per-frame=true $model/final.mdl "ark,t:gunzip -c $exp/gop/ali.JOB.gz|" \
      "ark,t:-" \| utils/apply_map.pl -f 2- $exp/gop/phone-to-pure-phone.int \| \
      gzip -c \>$exp/gop/ali-pure-phone.JOB.gz   || exit 1;
fi

if [ $stage -le 7 ]; then
  # The outputs of the binary compute-gop are the GOPs and the phone-level features.
  #
  # An example of the GOP result (extracted from "ark,t:$exp/gop/gop.3.txt"):
  # 4446-2273-0031 [ 1 0 ] [ 12 0 ] [ 27 -5.382001 ] [ 40 -13.91807 ] [ 1 -0.2555897 ] \
  #                [ 21 -0.2897284 ] [ 5 0 ] [ 31 0 ] [ 33 0 ] [ 3 -11.43557 ] [ 25 0 ] \
  #                [ 16 0 ] [ 30 -0.03224623 ] [ 5 0 ] [ 25 0 ] [ 33 0 ] [ 1 0 ]
  # It is in the posterior format, where each pair stands for [pure-phone-index gop-value].
  # For example, [ 27 -5.382001 ] means the GOP of the pure-phone 27 (it corresponds to the
  # phone "OW", according to "$exp/gop/phones-pure.txt") is -5.382001, indicating the audio
  # segment of this phone should be a mispronunciation.
  #
  # The phone-level features are in matrix format:
  # 4446-2273-0031  [ -0.2462088 -10.20292 -11.35369 ...
  #                   -8.584108 -7.629755 -13.04877 ...
  #                   ...
  #                   ... ]
  # The row number is the phone number of the utterance. In this case, it is 17.
  # The column number is 2 * (pure-phone set size), as the feature is consist of LLR + LPR.
  # The phone-level features can be used to train a classifier with human labels. See Hu's
  # paper for detail.
  $cmd JOB=1:$nj $exp/gop/log/compute_gop.JOB.log \
    compute-gop --phone-map=$exp/gop/phone-to-pure-phone.int $model/final.mdl \
      "ark,t:gunzip -c $exp/gop/ali-pure-phone.JOB.gz|" \
      "ark:$exp/probs_lpp_lpr/output.JOB.ark" \
      "ark,t:$exp/gop/gop.JOB.txt" "ark,t:$exp/gop/phonefeat.JOB.txt"   || exit 1;
  echo "Done compute-gop, the results: \"$exp/gop/gop.<JOB>.txt\" in posterior format."

  # We set -5 as a universal empirical threshold here. You can also determine multiple phone
  # dependent thresholds based on the human-labeled mispronunciation data.
  echo "The phones whose gop values less than -5 could be treated as mispronunciations."
fi
