#!/usr/bin/env bash

cd /home/ubuntu/kaldi/egs/gop/s5/

set -e

# Global configurations
stage=0
nj=1
cmd="run.pl"

. ./path.sh

if [ $# -ne 1 ]; then
   echo "Usage: $0 <wav-file>"
   echo "e.g.: $0 2020-11-08-user1.wav"
   exit 1;
fi

for f in $1; do
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

