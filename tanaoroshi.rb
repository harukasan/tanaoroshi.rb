# encoding: utf-8
#
# 今週はてブにブックマークしたページを教えてくれるスクリプト
# Authors:: harukasan <miruca@me.com>
# License:: MIT License
#

require 'open-uri'
require 'yaml'
require 'mustache'
require 'mail'
require 'nokogiri'
require 'settingslogic'

class Setting < Settingslogic
  source "./config.yml"
	load!
end

class Hatebu
  attr_accessor :title, :url, :summary, :content

  def self.get(options)
    url = self.url options
    puts "Getting #{url} ..."
    feed = Nokogiri::XML open(url)
    entries = feed.xpath('//xmlns:entry').collect do |entry|
      hatebu = self.new
      [:title, :summary, :content].each do |e|
        hatebu.instance_variable_set "@#{e}", entry.css(e.to_s).text
      end
      hatebu.instance_variable_set :@url, entry.xpath("xmlns:link[@rel='related']/@href").text
      hatebu
    end

    if options.key?(:page) and options[:page] == :all
      next_url = feed.xpath("/xmlns:feed/xmlns:link[@rel='next']/@href").text
      unless next_url.empty?
        entries << self.get(url: next_url)
      end
    end

    entries
  end

  def self.url(options)
    return options[:url] if options.key? :url

    opt = []
    opt << "date=#{options[:date].strftime("%Y%m%d")}" if options.key? :date
    opt << "tag=#{options[:tag]}" if options.key? :tag
    opt << "of=#{(options[:page].to_i - 1) * 20}" if options.key? :page and options[:page] != :all
    opt = opt.join("&amp;")
    
    "http://b.hatena.ne.jp/#{options[:user]}/atomfeed?#{opt}"
    
  end
end

title     = "今週ブックマークしたページ"
format    = <<-EOT
今週ブックマークしたページ
--------------------------
今週ブックマークしたページは{{bukumas.size}}件だったよ！

{{#bukumas}}
* {{title}}
  {{url}}
{{/bukumas}}
EOT

bukuma = (0..7).inject([]) do |b, d|
  b + Hatebu.get(user: Setting.username, date: (Time.now - d * 24 * 3600), page: :all)
end

body = Mustache.render format, bukumas: bukuma

Mail.deliver do
	delivery_method :smtp, {
		:address              => Setting.mail.address,
		:port                 => Setting.mail.port,
		:domain               => Setting.mail.domain,
		:user_name            => Setting.mail.from,
		:password             => Setting.mail.password,
		:authentication       => 'plain',
		:enable_starttls_auto => true
	}
	from    Setting.mail.from
	to      Setting.mail.to
	subject title
	body    body
end

