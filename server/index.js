const child_process = require("child_process")
const express = require("express")
const fs = require("fs")
const multer = require("multer")
const os = require("os")
const path = require("path")
const rimraf = require("rimraf")
const serveStatic = require("serve-static")
const upload = multer()

function parsePages(pages) {
    if (pages.match(/\d+-\d+/)) {
        const spl = pages.split("-")

        let str = []
        for (i = parseInt(spl[0]); i <= parseInt(spl[1]); i++) {
            str.push(i)
        }

        return str.join(",")
    }
    return pages
}

async function execScript(req, res) {
    if (!req.file) {
        res.send("The file must not be empty.")
        return
    }

    const file = req.file
    const pages = parsePages(req.body.pages.toString())
    const url = req.body.baseUrl
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sapebook2pdf-tmp-')) /* will be deleted */
    const cookieFilePath = path.join(tmpDir, "cookies.txt")
    const pdfOutPath = path.join("pdfs", Math.random().toString(36).substring(7) + ".pdf")

    fs.writeFileSync(cookieFilePath, file.buffer)

    res.set({ 'Content-Type': 'application/json; charset=utf-8',
              'Cache-Control': 'no-cache'});

    const child = child_process.execFile(
        "../sapebook2pdf",
        [cookieFilePath, url, tmpDir, pages, tmpDir, path.join("web", pdfOutPath)],
        (error, _stdout, _stderr) => {
            if (!error) {
                res.write(`\nDownload at: ${req.protocol}://${req.headers.host}/${pdfOutPath}`)
                res.end()
                rimraf.sync(tmpDir)
            } else {
                res.end()
                rimraf.sync(tmpDir)
            }
        }
    )

    for await (const data of child.stdout) {
        res.write(data)
    }
}

const app = express()
app.use(serveStatic("web", { index: ["index.html"] }))
app.post("/create", upload.single("cookies"), execScript)
app.listen(5000)
