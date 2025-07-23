require "mail"
require "pathname"
require "luca_record/io"

module LucaSupport
  class Mail
    include LucaRecord::IO

    def initialize(mail=nil, pjdir=nil)
      @pjdir = pjdir || Dir.pwd
      @config = load_config( Pathname(@pjdir) + "config.yml" )
      @mail = mail
      set_message_default
      @host = set_host
    end

    def deliver
      # mail gem accepts hash for 2nd param, not keywords
      @mail.delivery_method(:smtp, @host)
      @mail.deliver
    end

    def set_host
      {
        address: mail_config("address"),
        port: mail_config("port"),
        domain: mail_config("domain"),
        user_name: mail_config("user_name"),
        password: mail_config("password"),
        authentication: mail_config("authentication"),
        enable_starttls: mail_config("enable_starttls"),
        openssl_verify_mode: mail_config("openssl_verify_mode"),
        ssl: mail_config("ssl"),
        tls: mail_config("tls"),
      }
    end

    def mail_config(attr=nil)
      return nil if attr.nil?
      @config.dig("mail", attr)
    end

    def set_message_default
      @mail.from ||= @config.dig("mail", "from")
      @mail.cc ||= @config.dig("mail", "cc")
    end
  end
end
