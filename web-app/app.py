import flask
from flask import request, render_template
from werkzeug.utils import secure_filename
import subprocess, logging, os

from utils.gop_to_json import gop_to_json

app = flask.Flask(__name__)
logging.basicConfig(filename='app.log',
level=logging.DEBUG,
format='%(asctime)s %(levelname)s %(name)s %(threadName)s : %(message)s')

# dir to store uploaded wav files and transcripts
uploads_dir = os.path.join(app.instance_path, 'uploads')
if not os.path.isdir(uploads_dir):
    os.makedirs(uploads_dir)

@app.route("/")
def main():
    return render_template('index.html')

@app.route('/score/read', methods=['POST'])
def score_read():
    # saving transcript and audio
    transcript = request.form['transcript']
    audio = request.files['audio_data']
    wav_id = os.path.splitext(audio.filename)[0].replace('-', '_')
    transcript_path = os.path.join(uploads_dir, wav_id+'.txt')
    wav_path = os.path.join(uploads_dir, wav_id+'.wav')
    transcript_file = open(transcript_path, "w")
    transcript_file.write(transcript.upper())
    transcript_file.close()
    app.logger.info('Saving transcript file to ' + transcript_path)
    audio.save(wav_path)
    app.logger.info('Saving wav file to ' + wav_path)

    # run gop script
    gop_dir = '/home/ubuntu/kaldi/egs/gop/s5'
    result = subprocess.run([gop_dir+'/gop_v1.sh', wav_path, transcript_path], stdout=subprocess.PIPE)
    app.logger.info('Running script for ' + audio.filename)
    if (result.returncode):
        app.logger.info(result.stdout)
        app.logger.error('Error running gop script:\n' + result.stderr)
        return "Error running scoring script", 500
    else:
        gop_result_json = gop_to_json(wav_id)
        app.logger.info('GOP result for ' + audio.filename + ' is:\n' + gop_result_json)
        return gop_result_json

if __name__=="__main__":
    app.run(ssl_context='adhoc', host='0.0.0.0', port=8080)

 
