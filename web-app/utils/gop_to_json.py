import pandas as pd
import json
import os
import re

def gop_to_json(wav_id):
    web_dir = '/home/ubuntu/kaldi/egs/gop/s5/web'
    gop_path = os.path.join(web_dir, wav_id+'/exp/gop/gop.1.txt')
    phones_dict_path = os.path.join(web_dir, wav_id+'/exp/gop/phones-pure.txt')
    with open(gop_path, 'r') as gop_file:
        gop_text = gop_file.read().replace('\n', '')
    phones_dict = pd.read_csv(phones_dict_path, header=None, delimiter=r"\s+")
    result = []
    for phone_gop in gop_text.split("[")[1:]:
        phone, gop = phone_gop.split(" ")[1:3]
        result.append([phones_dict.iloc[int(phone)][0],gop])
    return json.dumps([{x:y} for x,y in result])