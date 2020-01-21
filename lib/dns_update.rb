# frozen_string_literal: true

require 'yaml'
require 'httparty'
require 'json'

module CloudFlare
  class UpdateDns
    include HTTParty
    debug_output $stdout
    base_uri 'https://api.cloudflare.com/client/v4'

    def initialize
      @config = YAML.load_file('./dns.yml')

      @options = {
        headers: {
          'X-Auth-Key' => @config['key'],
          'X-Auth-Email' => @config['email'],
          'Content-Type' => 'application/json'
        },
        verify: false
      }
    end

    def run
      @config['domains'].map do |domain|
        update_zone_dns domain
      end
    end

    def list_zones
      self.class.get('/zones', @options)
    end

    def list_dns_records(identifier = '')
      self.class.get("/zones/#{identifier}/dns_records", @options)
    end

    def update_dns(identifier, record, new_ip)
      opts = {
        body: {
          'type' => record['type'],
          'name' => record['name'],
          'content' => new_ip,
          'ttl' => {}
        }.to_json
      }
      self.class.put("/zones/#{identifier}/dns_records/#{record['id']}",
                     opts.merge!(@options))
    end

    def update_zone_dns(domain)
      list_zones['result'].map do |zone|
        next unless domain == zone['name']

        list_dns_records(zone['id'])['result'].map do |record|
          next unless @config['dns_record_types'].include? record['type']

          new_ip = `#{@config['command']}`
          puts 'Updating DNS Record type' \
               " #{record['type']} for domain #{zone['name']}" \
               " with the new content #{new_ip}"
          update_dns zone['id'], record, new_ip
        end
      end
    end
  end
end
