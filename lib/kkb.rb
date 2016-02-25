require 'net/http'
require 'uri'
require 'yaml'
require 'jkf'
require 'clipboard'

module Kkb
  class << self
    def run
      load_config
      ki2 = kif_to_ki2
      post(ki2)
    rescue Jkf::Parser::ParseError
      puts "KIFのパースに失敗しました"
      puts "Clipboard:"
      puts Clipboard.paste
    rescue => e
      puts e
    end

    private

    def load_config
      @config = YAML.load_file(File.expand_path("~/.config/kkb/kkb.yml"))
    end

    def kif_to_ki2
      parser = Jkf::Parser::Kif.new
      jkf = parser.parse(Clipboard.paste)

      jkf["header"].tap do |header|
        header["先手"] = "" if header.key?("先手") && !@config[:include_names].include?(header["先手"])
        header["後手"] = "" if header.key?("後手") && !@config[:include_names].include?(header["後手"])
        header["上手"] = "" if header.key?("上手") && !@config[:include_names].include?(header["上手"])
        header["下手"] = "" if header.key?("下手") && !@config[:include_names].include?(header["下手"])
      end

      converter = Jkf::Converter::Ki2.new
      ki2 = converter.convert(jkf)
      ki2
    end

    def post(message)
      uri = URI.parse("http://jbbs.shitaraba.net/bbs/write.cgi/#{@config[:genre]}/#{@config[:bbs_id]}/#{@config[:thread_id]}/")
      submit = '書き込む'
      cookie = get()

      form_data = {
        'DIR'     => @config[:genre].to_s,
        'BBS'     => @config[:bbs_id].to_s,
        'TIME'    => Time.now.to_i.to_s,
        'NAME'    => @config[:name].encode('EUC-JP', 'UTF-8') || '',
        'MAIL'    => @config[:email] || 'sage',
        'KEY'     => @config[:thread_id].to_s,
        'MESSAGE' => message.to_s.encode('EUC-JP', 'UTF-8'),
        'submit'  => submit.to_s.encode('EUC-JP', 'UTF-8')
      }
      form_data

      req = Net::HTTP::Post.new(uri.path, {
        'Referer'    => get_url,
        'User-Agent' => "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1)",
        'Cookie'     => cookie.map{|(k,v)| "#{k}=#{v}"}.join(';')
      })
      req.set_form_data(form_data)
      response = nil
      Net::HTTP.new(uri.host, uri.port).start {|http| response = http.request(req) }
    end

    def get_url
      "http://jbbs.shitaraba.net/bbs/read.cgi/#{@config[:genre]}/#{@config[:bbs_id]}/#{@config[:thread_id]}/"
    end

    def get
      cookie = {}

      uri = URI.parse(get_url)

      Net::HTTP.start(uri.host){|http|
        response, = http.get(uri.path)

        response.get_fields('Set-Cookie').each{|str|
          k,v = str[0...str.index(';')].split('=')
          cookie[k] = v
        }
      }
      cookie
    end
  end
end
