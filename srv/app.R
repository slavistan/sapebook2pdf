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
	titlePanel("Hello Shiny!"),

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

			# Output: PDF preview
			htmlOutput('preview')

		)
	)
)

# Define server logic required to draw a histogram ----
server <- function(input, output) {
	# Reactive: Aggregated console output
	reactives <- reactiveValues(console="", pdfpath="")
	shinyjs::disable("buttonDownload")

	observeEvent(input$buttonGo, {

		##
		## Check inputs
		##
		printf("Checking inputs ...\n")
		if (is.null(input$pgnum) ||
			is.null(input$baseUrl) ||
			is.null(input$cookiesFile)) {

			reactives$console <- "Missing inputs."
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
				reactives$console <- paste(reactives$console, "\n", paste(ret, collapse="\n"))
				incProgress(incr, detail=paste0("Page ", pgnum, "/", input$pgnum))
			}
		})

		##
		## Check fonts
		##
		printf("Checking fonts ...\n")
		ret <- system2("sapebook2pdf",
				args=c("@", "checkfonts", reactives$tmpdir),
				stdout=T, stderr=T)
		retcode <- ifelse(toString(attr(ret, "status")) == "", 0, as.integer(attr(ret, "status")))
		reactives$console <- paste(reactives$console, "\n", paste(ret, collapse="\n"))

		##
		## Generate PDF pages
		##
		withProgress(message='Generate PDFs', value=0, {
			printf("Generating PDF pages ...\n")

			pages <- seq(1, input$pgnum)
			incr <- 1/input$pgnum
			for (pgnum in pages) {
				ret <- system2("sapebook2pdf",
						args=c("@", "_genpdf", reactives$tmpdir, reactives$tmpdir, pgnum),
						stdout=T, stderr=T)
				retcode <- ifelse(toString(attr(ret, "status")) == "", 0, as.integer(attr(ret, "status")))
				reactives$console <- paste(reactives$console, "\n", paste(ret, collapse="\n"))
				incProgress(incr, detail=paste0("Page ", pgnum, "/", input$pgnum))
			}
		})

			##
			## Collate PDF pages
			##
			printf("Collating PDF pages ...\n")
			reactives$pdfpath <- paste0(reactives$tmpdir, "/ebook.pdf")
			ret <- system2("sapebook2pdf",
					args=c("@", "collatepdfs", reactives$tmpdir, reactives$pdfpath),
					stdout=T, stderr=T)
			retcode <- ifelse(toString(attr(ret, "status")) == "", 0, as.integer(attr(ret, "status")))
			reactives$console <- paste(reactives$console, "\n", paste(ret, collapse="\n"))

		shinyjs::enable("buttonDownload")
	})

	output$infoText <- renderText({
		return(reactives$console)
	})
	
	output$buttonDownload <- downloadHandler(
		filename = "ebook.pdf",
		content = function(file) {
			file.copy(reactives$pdfpath, file)
		},
		contentType = 'application/pdf'
	)
	
	output$preview <- renderText({
		# TODO: Pdf preview here
	})

}


app <- shinyApp(ui=ui, server=server, options=list(autoreload=T))
port <- as.integer(Sys.getenv("PORT", unset=5000))
host <- "0.0.0.0"
runApp(app, port=port, host=host)

# TODO: Document shiny app
