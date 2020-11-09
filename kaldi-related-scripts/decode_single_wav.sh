# Global configurations
nj=1
cmd="run.pl"
stage=1

if [ $# -ne 1 ]; then
   echo "Usage: $0 <wav-file>"
   echo "e.g.: $0 web/2020-11-08-user1.wav"
   exit 1;
fi

for f in $1; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1;
done

wav_id=$(basename -s .wav $1 | sed s/-/_/g)
ivectors=web/$wav_id/ivectors
data=web/$wav_id/data

if [ ! -d "$ivectors" ] || [ ! -d "$data" ]; then
  make_mfcc_cmvn_ivectors_wav_file.sh $1 
fi

librispeech_eg=../../librispeech/s5
model=$librispeech_eg/exp/chain_cleaned/tdnn_1d_sp
lang=$librispeech_eg/data/lang_test_tgsmall
graph_dir=$librispeech_eg/exp/chain_cleaned/tdnn_1d_sp/graph_tgsmall

exp=web/$wav_id/exp

if [ ! -d "$graph_dir" ]; then
  # make decoding graph if not existing
  utils/mkgraph.sh --self-loop-scale 1.0 --remove-oov $lang $model $graph_dir
fi

if [ $stage -le 0 ]; then
  # decode using small language model
  steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
    --nj $nj --cmd "$cmd" --online-ivector-dir $ivectors \
    $graph_dir $data $model/decode_tgsmall

  rm -r $exp/decode_tgsmall
  mv $model/decode_tgsmall $exp/decode_tgsmall
fi

if [ $stage -le 1 ]; then
  # convert lattice to text
  lattice-copy "ark:gunzip -c $exp/decode_tgsmall/lat.1.gz |" ark,t:- | utils/int2sym.pl -f 3 $graph_dir/words.txt > $exp/decode_tgsmall/lat.1.txt
  show_lattice.sh --mode save --format pdf $wav_id $exp/decode_tgsmall/lat.1.gz $graph_dir/words.txt
  rm $exp/decode_tgsmall/$wav_id.pdf
  mv $wav_id.pdf $exp/decode_tgsmall/$wav_id.pdf
fi


