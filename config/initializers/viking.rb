enki_config = Enki::Config.default

require 'pp'
pp enki_config

Viking.logger = Rails.logger
Viking.default_engine = enki_config[:viking][:engine]
Viking.connect_options = {
  :api_key => enki_config[:viking][:api_key], 
  :blog    => enki_config[:url]
}