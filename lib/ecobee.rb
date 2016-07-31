require 'pp'
require 'json'
require 'net/http'

require "ecobee/client"
require "ecobee/register"
require "ecobee/token"
require "ecobee/version"

module Ecobee
  DEFAULT_INTERVAL = 30
  PRE_REFRESH_INTERVAL = 30
  GEM_APP_KEY = 'b7OYXZiCUfCB5um7ppmykURBOORPJucc'
  GEM_APP_KEY = 'Hwfou8ocNT5PSVIkUS0HxsCDILrRneG1'
  SCOPES = [:smartRead, :smartWrite]
  
  URI_HOST = 'api.ecobee.com'
  URI_PORT = 443
  URI_BASE= "https://#{URI_HOST}"
  URI_API = "#{URI_BASE}/1/"
  URI_PIN = "#{URI_BASE}/authorize?response_type=ecobeePin&client_id=%s&scope=%s"
  URI_TOKEN = "#{URI_BASE}/token"
end
