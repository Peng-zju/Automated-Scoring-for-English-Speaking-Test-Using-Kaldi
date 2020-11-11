from subprocess import run, PIPE
import flask
from flask import request, render_template
import os
from werkzeug.utils import secure_filename

app = flask.Flask(__name__)

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
    audio.save(os.path.join(uploads_dir, secure_filename(audio.filename)))
    return "success"

# Start the server, continuously listen to requests.
if __name__=="__main__":
    # For local development, set to True:
    app.run(debug=True)
    # For public web serving:
    #app.run(host='0.0.0.0')
 