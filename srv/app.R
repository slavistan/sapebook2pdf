library(shiny)
library(R.utils)

# Define UI for app that draws a histogram ----
ui <- fluidPage(
	shinyjs::useShinyjs(),
	tags$head(
	   tags$style(HTML("
		.btn { width: 100%; }
		#infoText { max-height: 200px }
		"
		)
	)),

	# App title ----
	titlePanel("Generate PDFs from SAP Learning Hub Ebooks"),

	# Sidebar layout with input and output definitions ----
	sidebarLayout(

		# Sidebar panel for inputs ----
		sidebarPanel(

			# Input: cookies.txt upload
			fileInput("cookiesFile", "Upload Cookies File",
				multiple = FALSE,
				accept = c("text/plain")),

			# Input: Baseurl
			textInput("baseUrl", "Base URL",
				value="https://saplearninghub.plateau.com/icontent_e/CUSTOM_eu/sap/self-managed/ebook/BC100_EN_Col18/"),

			# Input: Lower page num
			numericInput("pgnum", "Number of Pages",
				min=1,
				value=1),

			fluidRow(
				# Input: Execute button
				column(6, actionButton("buttonGo", "Convert")),

				# Input: Download button
				column(6, downloadButton("buttonDownload", "Download"))
			  ),

			hr(),
			verbatimTextOutput(outputId = "infoText"),
		),

		# Main panel for displaying outputs ----
		mainPanel(

			imageOutput("pdfPreview")
		)
	)
)

# Define server logic required to draw a histogram ----
server <- function(input, output) {
	# Reactive: Aggregated console output
	reactives <- reactiveValues(console="", pdfpath="", page1.svg="")
	shinyjs::disable("buttonDownload")

	observeEvent(input$buttonGo, {
		shinyjs::disable("buttonGo")
		shinyjs::disable("buttonDownload")
		reactives$console <- ""
		reactives$page1.svg <- ""


		##
		## Check inputs
		##
		printf("Checking inputs ...\n")
		if (is.null(input$pgnum) ||
			is.null(input$baseUrl) ||
			is.null(input$cookiesFile)) {

			reactives$console <- "Missing inputs."
			shinyjs::enable("buttonGo")
			return()
		}
		reactives$console <- ""

		##
		## Check connection
		##
		printf("Checking connection ...\n")
		ret <- system2("sapebook2pdf",
				args=c("@", "checkconn", input$cookiesFile$datapath, input$baseUrl),
				stdout=T, stderr=T)
		retcode <- ifelse(toString(attr(ret, "status")) == "", 0, as.integer(attr(ret, "status")))
		# ^--- this is exactly why using R for anything outside of statistics is bullshit
		reactives$console <- paste(ret, collapse="\n")
		if (retcode != 0) {
			shinyjs::enable("buttonGo")
			return()
		}

		##
		## Download SVGs
		##
		withProgress(message='Download SVGs', value=0, {
			reactives$tmpdir <- tempdir()
			printf("Downloading SVGs ... tmpdir = '%s'\n", reactives$tmpdir)

			pages <- seq(1, input$pgnum)
			incr <- 1/input$pgnum
			for (pgnum in pages) {
				ret <- system2("sapebook2pdf",
						args=c("@", "_dlsvg", input$cookiesFile$datapath, input$baseUrl, reactives$tmpdir, pgnum),
						stdout=T, stderr=T)
				retcode <- ifelse(toString(attr(ret, "status")) == "", 0, as.integer(attr(ret, "status")))
				reactives$console <- paste0(reactives$console, "\n", paste0(ret, collapse="\n"))
				incProgress(incr, detail=paste0("Page ", pgnum, "/", input$pgnum))
			}
		})
		reactives$page1.svg <- paste0(reactives$tmpdir, "/page1.svg")

		##
		## Check fonts
		##
		printf("Checking fonts ...\n")
		ret <- system2("sapebook2pdf",
				args=c("@", "checkfonts", reactives$tmpdir),
				stdout=T, stderr=T)
		retcode <- ifelse(toString(attr(ret, "status")) == "", 0, as.integer(attr(ret, "status")))
		reactives$console <- paste0(reactives$console, "\n", paste0(ret, collapse="\n"))

		##
		## Generate PDF pages
		##
		withProgress(message='Generate PDFs', value=0, {
			printf("Generating PDF pages ...\n")

			incr <- 1/input$pgnum
			for (pgnum in pages) {
				ret <- system2("sapebook2pdf",
						args=c("@", "_genpdf", reactives$tmpdir, reactives$tmpdir, pgnum),
						stdout=T, stderr=T)
				retcode <- ifelse(toString(attr(ret, "status")) == "", 0, as.integer(attr(ret, "status")))
				reactives$console <- paste0(reactives$console, "\n", paste0(ret, collapse="\n"))
				incProgress(incr, detail=paste0("Page ", pgnum, "/", input$pgnum))
			}
		})

		withProgress(message='Collate PDFs', value=0.01, {
			##
			## Collate PDF pages
			##
			printf("Collating PDF pages ...\n")
			reactives$pdfpath <- paste0(reactives$tmpdir, "/ebook.pdf")
			ret <- system2("sapebook2pdf",
					args=c("@", "collatepdfs", reactives$tmpdir, reactives$pdfpath),
					stdout=T, stderr=T)
			retcode <- ifelse(toString(attr(ret, "status")) == "", 0, as.integer(attr(ret, "status")))
			reactives$console <- paste0(reactives$console, "\n", paste(ret, collapse="\n"))
		})

		shinyjs::enable("buttonDownload")
		shinyjs::enable("buttonGo")
	})

	output$infoText <- renderText({
		return(reactives$console)
	})

	output$pdfPreview <- renderImage({
		if (!is.null(reactives$page1.svg)) {
			list(src=reactives$page1.svg, contentType="image/svg+xml")
		}
	}, deleteFile=F)
	
	output$buttonDownload <- downloadHandler(
		filename = "ebook.pdf",
		content = function(file) {
			file.copy(reactives$pdfpath, file)
		},
		contentType = 'application/pdf'
	)

}


app <- shinyApp(ui=ui, server=server, options=list(autoreload=T))
port <- as.integer(Sys.getenv("PORT", unset=5000))
host <- "0.0.0.0"
runApp(app, port=port, host=host)
