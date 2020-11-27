from flask import Flask, send_file, render_template, request, redirect, url_for, flash, make_response
import os
import subprocess
import tempfile

app = Flask(__name__)

@app.route("/", methods=["GET"])
def index():
    return render_template("index.html")

@app.route("/", methods=["POST"])
def upload_file():
    cookies_ul = request.files["cookies"]
    baseurl = request.form["baseurl"]
    pages = request.form["pages"]
    if cookies_ul.name == "" or baseurl == "" :
        return "Input Error"

    tmpdir = tempfile.mkdtemp()
    pdfout = os.path.join(tmpdir, "ebook.pdf")
    cookies = os.path.join(tmpdir, cookies_ul.filename)
    cookies_ul.save(cookies)

    ret = subprocess.run(["sapebook2pdf",
        f"--cookies={cookies}",
        f"--baseurl={baseurl}",
        f"--pages={pages}",
        f"--pdfout={pdfout}"],
        cwd=tmpdir)

    return send_file(
        pdfout,  # file path or file-like object
        'application/pdf',
        as_attachment=True,
        attachment_filename="ebook.pdf")
