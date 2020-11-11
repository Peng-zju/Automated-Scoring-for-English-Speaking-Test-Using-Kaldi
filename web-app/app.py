import subprocess
import flask
from flask import request, render_template
import os
from werkzeug.utils import secure_filename
import logging

app = flask.Flask(__name__)
logging.basicConfig(filename='app.log',
level=logging.DEBUG,
format='%(asctime)s %(levelname)s %(name)s %(threadName)s : %(message)s')

uploads_dir = os.path.join(app.instance_path, 'uploads')
if not os.path.isdir(uploads_dir):
    os.makedirs(uploads_dir)

@app.route("/")
def main():
    return render_template('index.html')

@app.route('/score/read', methods=['POST'])
def score_read():
    transcript = request.form['transcript']
    audio = request.files['audio_data']
    audio_save_path = os.path.join(uploads_dir, secure_filename(audio.filename))
    audio.save(audio_save_path)

    # run gop script
    gop_dir = '/home/ubuntu/kaldi/egs/gop/s5'
    result = subprocess.run([gop_dir+'/make_mfcc_cmvn_ivectors_wav_file.sh', audio_save_path], stdout=subprocess.PIPE)
    app.logger.info('Calling MFCC script for ' + audio.filename)
    if (result.returncode):
        app.logger.info(result.stdout)
        app.logger.error(result.stderr)
    return "success"

# Start the server, continuously listen to requests.
if __name__=="__main__":
    # For local development, set to True:
    app.run(ssl_context='adhoc', host='0.0.0.0', port=8080)
    # For public web serving:
    #app.run(host='0.0.0.0')
 
