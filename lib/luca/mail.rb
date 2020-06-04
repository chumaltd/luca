require "mail"
require "pathname"
require "luca/io"

module Luca
  class Mail
    include Luca::IO

    def initialize(mail=nil)
      @config = load_config( Pathname(Dir.pwd) + "config.yml" )
      @mail = mail
      @host = set_host
    end

    def deliver
      mail = ::Mail.new do
      end
      # mail gem accepts hash for 2nd param, not keywords
      @mail.delivery_method(:smtp, @host)
      @mail.deliver
    end

    def set_host
      {
        authentication: :plain,
        address: mail_config("address"),
        port: mail_config("port"),
        doomain: mail_config("domain"),
        user_name: mail_config("user_name"),
        password: mail_config("password")
      }
    end

    def mail_config(attr=nil)
      return nil if attr.nil?
      @config.dig("mail", attr)
    end

  end
end
