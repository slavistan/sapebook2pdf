const child_process = require("child_process")
const express = require("express")
const fs = require("fs")
const multer = require("multer")
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
    const file = req.file
    const pages = parsePages(req.body.pages.toString())
    const url = req.body.baseUrl

    const folder = fs.mkdtempSync("out/")

    const cookieFilePath = path.join(folder, "cookies.txt")
    fs.writeFileSync(cookieFilePath, file.buffer)
    const filePath = path.join("pdfs", Math.random().toString(36).substring(7) + ".pdf")

    res.header("Cache-Control", "no-cache")
    res.header("Content-Type", "text/event-stream")

    const child = child_process.execFile(
        "../sapebook2pdf",
        [cookieFilePath, url, folder, pages, folder, path.join("web", filePath)],
        (error, _stdout, _stderr) => {
            if (!error) {
                res.write(`\nDownload at: ${req.protocol}://${req.headers.host}/${filePath}`)
                res.end()
                rimraf.sync(folder)
            } else {
                res.end()
                rimraf.sync(folder)
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
app.listen(3000)
