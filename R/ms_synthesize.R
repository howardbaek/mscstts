
#' Convert text to speech using Speech Synthesis Markup Language (SSML)
#'
#' @param script A character vector of lines to be spoken
#' @param token An authentication token, base-64 encoded usually from
#' @param api_key Microsoft Cognitive Services API key, if token is not
#'   provided. \code{\link{ms_get_tts_token}}.  If not provided, will be created
#'   from \code{\link{ms_get_tts_token}}
#' @param gender Sex of the Speaker
#' @param language Language to be spoken, must be from
#'   \code{\link{ms_language_codes}}
#' @param output_format Format of the output, see
#'   \url{https://docs.microsoft.com/en-us/azure/cognitive-services/speech-service/how-to-migrate-from-bing-speech}
#'   for more information
#' @param escape Should non-standard characters be substituted?  Should not be
#'   used if \code{script} has SSML tags. See \code{\link{ms_create_ssml}}
#' @param voice full voice name, usually from
#'   \code{\link{ms_language_to_ms_name}}.  Will override language and gender.
#' @param ... Additional arguments to send to \code{\link{POST}}
#'
#' @return A list of the request, content, token, and `SSML`.
#' @note The content is likely in a binary format and the output depends on the
#'   `output_format` chosen.  For example, if the `output_format` is an `MP3`,
#'   then see below example
#'
#' @examples \dontrun{
#' if (ms_have_tts_key()) {
#' res = ms_synthesize(
#' script = "hey, how are you doing? I'm doing pretty good",
#' output_format = "audio-16khz-128kbitrate-mono-mp3")
#' tmp <- tempfile(fileext = ".mp3")
#' writeBin(res$content, con = tmp)
#' mp3 = tuneR::readMP3(tmp)
#' }
#'
#' }
#' @export
#' @importFrom httr POST add_headers stop_for_status content content_type
ms_synthesize = function(
    script,
    token = NULL,
    api_key = NULL,
    gender = c("Female", "Male"),
    language = "en-US",
    voice = NULL,
    output_format = c("raw-16khz-16bit-mono-pcm", "raw-8khz-8bit-mono-mulaw",
                      "riff-8khz-8bit-mono-alaw", "riff-8khz-8bit-mono-mulaw",
                      "riff-16khz-16bit-mono-pcm", "audio-16khz-128kbitrate-mono-mp3",
                      "audio-16khz-64kbitrate-mono-mp3", "audio-16khz-32kbitrate-mono-mp3",
                      "raw-24khz-16bit-mono-pcm", "riff-24khz-16bit-mono-pcm",
                      "audio-24khz-160kbitrate-mono-mp3", "audio-24khz-96kbitrate-mono-mp3",
                      "audio-24khz-48kbitrate-mono-mp3"),
    escape = FALSE,
    region = NULL,
    api = c("tts", "bing"),
    ...
){

  region = ms_region(region)
  if (!is.null(voice)) {
    L = ms_voice_info(voice,
                      token = token,
                      api_key = api_key,
                      region = region)
  } else {
    L = ms_validate_language_gender(
      language = language,
      gender = gender)
  }
  language = L$language
  gender = L$gender
  voice = L$full_name[1]

  synth_url = ms_synthesize_api_url(
    api = api,
    region = region
  )

  if (is.null(token)) {
    token = ms_get_tts_token(api_key = api_key,
                             region = region)$token
  }

  # Create a request
  req <- httr2::request(synth_url)

  # Specify HTTP headers
  req <- req %>%
    httr2::req_headers(
      `Content-Type` = "application/ssml+xml",
      `X-Microsoft-OutputFormat` = "riff-24khz-16bit-mono-pcm",
      `Authorization` = paste("Bearer",  token),
      `User-Agent` = "MyTextToSpeech",
      Host = "westus.tts.speech.microsoft.com") %>%
    httr2::req_body_raw("<speak version='1.0' xml:lang='en-US'><voice xml:lang='en-US'
                        xml:gender='Male' name='Microsoft Server Speech Text to Speech Voice
                        (en-US, GuyNeural)'>Microsoft Speech Service Text-to-Speech API</voice></speak>")

  # Perform a request and fetch the response
  resp <- req %>% httr2::req_perform()

  # Transfer binary data to WAV file
  output <- tempfile(fileext = ".wav")
  writeBin(resp$body, con = output)

  httr::stop_for_status(res)
  out = content(res)
  class(token) = "token"

  L = list(
    request = res,
    ssml = ssml,
    content = out,
    token = token,
    output_format = output_format
  )
  return(L)
}

#' Read Synthesized output
#'
#' @param output List from \code{\link{ms_synthesize}} with elements
#' \code{output_format} and \code{content}
#'
#' @note The \code{tuneR} package cannot read all different types of
#' the output here.
#'
#' @return A Wave Object
#' @export
ms_read_synthesis = function(output) {
  tmp = tempfile()
  writeBin(output$content, con = tmp)
  output_format = output$output_format
  wav = grepl("riff", tolower(output_format))
  mp3 = grepl("mp3", tolower(output_format))
  if (!wav & !mp3) {
    warning("No format determined, assuming it's a WAV")
    wav = TRUE
  }

  if (wav) {
    out = tuneR::readWave(tmp)
  }
  if (mp3) {
    out = tuneR::readMP3(tmp)
  }
  return(out)
}


#' @rdname ms_synthesize
#' @param region Subscription region for your key.
#' See \url{https://docs.microsoft.com/en-us/azure/cognitive-services/speech-service/overview#reference-docs}
#'
#' @export
ms_region = function(region = ms_regions()) {
  if (missing(region)) {
    region = getOption("ms_region")
  }
  if (any(!region %in% ms_regions())) {
    warning("Some regions not in ms_regions, use at your own risk")
    stopifnot(length(region) >= 1)
    region = region[1]
  } else {
    region = match.arg(region)
  }
  return(region)
}

#' @rdname ms_synthesize
#' @export
#' @examples
#' ms_regions()
ms_regions = function() {
  c("westus",
    "westus2",
    "australiaeast",
    "brazilsouth",
    "canadacentral",
    "centralus",
    "eastasia",
    "eastus",
    "eastus2",
    "francecentral",
    "centralindia",
    "japaneast",
    "japanwest",
    "koreacentral",
    "northcentralus",
    "northeurope",
    "southcentralus",
    "southeastasia",
    "uksouth",
    "westeurope")
}

#' @rdname ms_synthesize
#' @export
ms_set_region = function(
    region = ms_regions()) {
  region = match.arg(region)
  options(ms_region = region)
  return(region)
}


#' Create URL Endpoint that allows you to convert text to speech
#' @rdname ms_synthesize
#' @param api Chose API to authorize on (\code{tts} for text to speech or
#'   \code{bing} for Bing text to speech API)
#' @export
ms_synthesize_api_url = function(
    api = c("tts", "bing"),
    region = NULL
){
  api = match.arg(api)

  region = ms_region(region)
  synth_url = switch(
    api,
    bing = paste0(
      'https://speech.platform.bing.com/',
      'synthesize'),
    tts = paste0("https://", region,
                 ".tts.speech.microsoft.com/",
                 "cognitiveservices/v1")
  )
  return(synth_url)
}
