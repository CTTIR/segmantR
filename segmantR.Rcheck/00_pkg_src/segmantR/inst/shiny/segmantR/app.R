library(shiny)

.sg_env <- getOption("segmantR.app_env")

ui <- fluidPage(
  titlePanel("segmantR"),
  sidebarLayout(
    sidebarPanel(
      selectInput(
        "example",
        "Example dataset",
        choices = c("he_breast", "fluorescence_nuclei", "multiplex_4ch"),
        selected = "he_breast"
      ),
      actionButton("load", "Load example"),
      hr(),
      helpText(
        "This is a minimal launcher for the segmantR Shiny app. ",
        "Pre-loaded image and mask objects, when supplied to ",
        "sg_run_app(image, mask), are available in the session."
      )
    ),
    mainPanel(
      h4("Image"),
      plotOutput("image_plot", height = "400px"),
      h4("Mask"),
      plotOutput("mask_plot", height = "400px"),
      verbatimTextOutput("info")
    )
  )
)

server <- function(input, output, session) {
  state <- reactiveValues(
    image = if (!is.null(.sg_env)) .sg_env$image else NULL,
    mask  = if (!is.null(.sg_env)) .sg_env$mask else NULL
  )

  observeEvent(input$load, {
    state$image <- segmantR::sg_example_image(input$example)
    state$mask  <- segmantR::sg_example_mask(input$example)
  })

  output$image_plot <- renderPlot({
    req(state$image)
    pixels <- state$image$pixels
    if (length(dim(pixels)) == 3L) pixels <- pixels[, , 1L]
    graphics::image(t(pixels)[, nrow(pixels):1L],
                    col = grDevices::gray.colors(64L), axes = FALSE)
  })

  output$mask_plot <- renderPlot({
    req(state$mask)
    print(segmantR::sg_plot_mask(state$mask))
  })

  output$info <- renderPrint({
    list(image = state$image, mask = state$mask)
  })
}

shinyApp(ui, server)
