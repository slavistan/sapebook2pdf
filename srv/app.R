library(shiny)
library(R.utils)

# Define UI for app that draws a histogram ----
ui <- fluidPage(

	# App title ----
	titlePanel("Hello Shiny!"),

	# Sidebar layout with input and output definitions ----
	sidebarLayout(

		# Sidebar panel for inputs ----
		sidebarPanel(

			# Input: cookies.txt upload
			fileInput("cookiesFile", "Choose cookies file",
				multiple = FALSE,
				accept = c("text/plain")),

			# Input: Baseurl
			textInput("baseUrl", "Base URL (location of index.html)",
				value="https://saplearninghub.plateau.com/icontent_e/CUSTOM_eu/sap/self-managed/ebook/BC100_EN_Col18/"),

			# Input: Lower page num
			numericInput("pgnumLow", "First page",
				min=1,
				value=1),

			# Input: Upper page num
			numericInput("pgnumHigh", "Last page",
				min=1,
				value=2),

			# Input: Execute button
			actionButton("buttonGo", "Execute",
				width="100%")
		),

		# Main panel for displaying outputs ----
		mainPanel(

			textOutput(outputId = "cookiesPath"),

			# Output: Live debugging information
			verbatimTextOutput(outputId = "infoText"),

		)
	)
)

# Define server logic required to draw a histogram ----
server <- function(input, output, session) {
	# Reactive: Aggregated console output
	reactives <- reactiveValues(console="")

	observe({
		input$buttonGo

		isolate({

		##
		## Check inputs
		##
		if (is.null(input$pgnumLow) || is.null(input$pgnumHigh) || input$pgnumLow > input$pgnumHigh ||
			is.null(input$baseUrl) ||
			is.null(input$cookiesFile)) {

			reactives$console <- "Missing inputs."
			return()
		}
		reactives$console <- ""

		##
		## Check connection
		##
		ret <- system2("sapebook2pdf",
				args=c("@", "checkconn", input$cookiesFile$datapath, input$baseUrl),
				stdout=T, stderr=T)
		retcode <- ifelse(toString(attr(ret, "status")) == "", 0, int(attr(ret, "status")))
		# ^--- this is exactly why using R for anything outside of statistics is bullshit
		reactives$console <- paste(reactives$console, "\n", paste(ret, collapse="\n"))
		if (retcode != 0) {
			return()
		}

		#
		# Download SVGs
		#
		reactives$tmpdir <- tempdir()
		pages <- paste(seq(input$pgnumLow, input$pgnumHigh), collapse=",")

		ret <- system2("sapebook2pdf",
				args=c("@", "dlsvgs", input$cookiesFile$datapath, input$baseUrl, reactives$tmpdir, pages),
				stdout=T, stderr=T)
		retcode <- ifelse(toString(attr(ret, "status")) == "", 0, int(attr(ret, "status")))
		reactives$console <- paste(reactives$console, "\n", paste(ret, collapse="\n"))

		##
		## Check fonts
		##
		ret <- system2("sapebook2pdf",
				args=c("@", "checkfonts", reactives$tmpdir),
				stdout=T, stderr=T)
		retcode <- ifelse(toString(attr(ret, "status")) == "", 0, int(attr(ret, "status")))
		reactives$console <- paste(reactives$console, "\n", paste(ret, collapse="\n"))

		##
		## Generate PDF pages
		##
		ret <- system2("sapebook2pdf",
				args=c("@", "genpdfs", reactives$tmpdir, reactives$tmpdir),
				stdout=T, stderr=T)
		retcode <- ifelse(toString(attr(ret, "status")) == "", 0, int(attr(ret, "status")))
		reactives$console <- paste(reactives$console, "\n", paste(ret, collapse="\n"))

		##
		## Collate PDF pages
		##
		ret <- system2("sapebook2pdf",
				args=c("@", "collatepdfs", reactives$tmpdir, paste0(reactives$tmpdir, "/ebook.pdf")),
				stdout=T, stderr=T)
		retcode <- ifelse(toString(attr(ret, "status")) == "", 0, int(attr(ret, "status")))
		reactives$console <- paste(reactives$console, "\n", paste(ret, collapse="\n"))

		}) # isolate()
	})

	output$infoText <- renderText({
		return(reactives$console)
	})

}


app <- shinyApp(ui=ui, server=server, options=list(autoreload=T))
port <- as.integer(Sys.getenv("PORT", unset=5000))
host <- "0.0.0.0"
runApp(app, port=port, host=host)
