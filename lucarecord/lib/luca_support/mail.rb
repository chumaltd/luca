require "mail"
require 'net/smtp'
require 'openssl'
require "pathname"
require "luca_record/io"

module LucaSupport
  class Mail
    include LucaRecord::IO

    def initialize(mail=nil, pjdir=nil)
      @pjdir = pjdir || Dir.pwd
      @config = self.class.load_config(@pjdir)
      @mail = mail
      set_message_default
      @host = set_host
    end

    def deliver
      # mail gem accepts hash for 2nd param, not keywords
      if conn = conn_with_tls
        @mail.delivery_method(:smtp_connection, { connection: conn })
      else
        @mail.delivery_method(:smtp, @host)
      end
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

    private

    def conn_with_tls
      ca_file = mail_config("ca_file")
      c_cert_path = mail_config("client_cert")
      c_key_path = mail_config("client_key")
      return nil if ca_file.nil? && c_cert_path.nil? && c_key_path.nil?

      tls_ctx = OpenSSL::SSL::SSLContext.new
      tls_ctx.cert = c_cert_path ?
                       OpenSSL::X509::Certificate.new(File.read(c_cert_path)) : nil
      tls_ctx.key = c_key_path ?
                      OpenSSL::PKey::RSA.new(File.read(c_key_path)) : nil
      tls_ctx.ca_file = ca_file
      tls_ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER if ca_file || @host[:openssl_verify_mode]

      conn = Net::SMTP.new(@host[:address], @host[:port])
      conn.enable_tls(tls_ctx)
      conn.start(helo: @host[:domain], user: @host[:user_name], password: @host[:password], authtype: @host[:authentication])
      conn
    end

  end
end
