#***** BEGIN LICENSE BLOCK *****
#
#Version: RTV Public License 1.0
#
#The contents of this file are subject to the RTV Public License Version 1.0 (the
#"License"); you may not use this file except in compliance with the License. You
#may obtain a copy of the License at: http://www.osdv.org/license12b/
#
#Software distributed under the License is distributed on an "AS IS" basis,
#WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for the
#specific language governing rights and limitations under the License.
#
#The Original Code is the Online Voter Registration Assistant and Partner Portal.
#
#The Initial Developer of the Original Code is Rock The Vote. Portions created by
#RockTheVote are Copyright (C) RockTheVote. All Rights Reserved. The Original
#Code contains portions Copyright [2008] Open Source Digital Voting Foundation,
#and such portions are licensed to you under this license by Rock the Vote under
#permission of Open Source Digital Voting Foundation.  All Rights Reserved.
#
#Contributor(s): Open Source Digital Voting Foundation, RockTheVote,
#                Pivotal Labs, Oregon State University Open Source Lab.
#
#***** END LICENSE BLOCK *****
require 'open-uri'

class Partner < ActiveRecord::Base
  acts_as_authentic do |c|
    c.crypto_provider = Authlogic::CryptoProviders::Sha512
    c.merge_validates_length_of_password_field_options({:minimum => 10})
  end
  validates_format_of :password, with: /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[$@$!%*?&])[A-Za-z\d$@$!%*?&]{10,}/, allow_blank: true
  
  include TimeStampHelper

  DEFAULT_ID = 1

  WIDGET_GIFS = [
    "rtv-234x60-v1.gif",
    "rtv-234x60-v1-sp.gif",
    "rtv-234x60-v2.gif",
    "rtv-234x60-v3.gif",
    "rtv-234x60-v3_es.gif",
    "rtv-100x100-v1.gif",
    "rtv-100x100-v2.gif",
    "rtv-100x100-v2_es.gif",
    "rtv-100x100-v3.gif",
    "rtv-100x100-v3_es.gif",
    "rtv-180x150-v1.gif",
    "rtv-180x150-v1_es.gif",
    "rtv-180x150-v2.gif",
    "rtv-200x165-v1.gif",
    "rtv-200x165-v2.gif",
    "rtv-200x165-v2_es.gif",
    "rtv-300x100-v1.gif",
    "rtv-300x100-v2.gif",
    "rtv-300x100-v3.gif",
    "rtv-468x60-v1.gif",
    "rtv-468x60-v1-sp.gif",
    "rtv-468x60-v2.gif",
    "rtv-468x60-v2_es.gif",
    "rtv-468x60-v3.gif"
  ]

  WIDGET_IMAGES = WIDGET_GIFS.collect do |widget|
    widget =~ /-(\d+)x(\d+)-/
    size = "#{$1} x #{$2}"
    [widget, widget.gsub(/-|\.gif/,''), size]
  end
  DEFAULT_WIDGET_IMAGE_NAME = "rtv234x60v1"

  CSV_GENERATION_PRIORITY = Registrant::REMINDER_EMAIL_PRIORITY

  attr_protected :crypted_password, :password_salt, :persistence_token, :perishable_token, :created_at, :updated_at, :api_key, :csv_ready, :csv_file_name, :from_email_verified_at, :from_email_verification_checked_at, :failed_login_count, :login_count, :last_request_at, :current_login_at, :current_login_ip, :last_login_ip, :grommet_csv_ready, :grommet_csv_file_name

  attr_accessor :tmp_asset_directory

  belongs_to :state, :class_name => "GeoState"
  belongs_to :government_partner_state, :class_name=> "GeoState"
  has_many :registrants

  def self.partner_assets_bucket
    if Rails.env.production?
      "rocky-partner-assets"
    else
      "rocky-partner-assets-#{Rails.env}"
    end
  end

  has_attached_file :logo, RockyConf.paperclip_options.to_hash.symbolize_keys.merge(:styles => { 
    :header => "75x45" 
  }).merge({
    fog_directory: partner_assets_bucket,
    fog_credentials: {
      provider: "AWS",
      aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    }
  })
  
  def custom_data
    return {
        "canvassing_session_timeout_length" => RockyConf.ovr_states.PA.api_settings.canvassing_session_timeout_minutes,
        "canvassing_validation_timeout_length" => RockyConf.ovr_states.PA.api_settings.canvassing_validation_timeout_minutes
      }
  rescue
    return {}
  end
  
  def header_logo_url
    self.logo(:header)
  end
  
  def local_logo_original_dir
    Rails.root.join("public/system/logos/#{id}/original")
  end
  
  def upload_local_logo
    Dir.glob(local_logo_original_dir.join('*.*')).each do |fn|
      self.logo = File.open(fn)
      self.save!
    end
  end
  
  def self.sync_all_logos
    Partner.all.each do |p|
      p.upload_local_logo
    end
  end
  

  serialize :government_partner_zip_codes
  serialize :replace_system_css, Hash

  before_validation :reformat_phone
  before_validation :set_default_widget_image
  before_validation :detect_from_email_change

  before_create :generate_api_key
  
  validate :check_valid_logo_url, :check_valid_partner_css_download_url
  validate :government_partner_zip_specification
  validate :check_valid_registration_instructions_url_format
  validates :registration_instructions_url, :url_format=>true
  
  after_save :write_partner_css_download_contents

  validates_presence_of :name
  validates_presence_of :url
  validates_format_of :url, with: /\Ahttps?:\/\//, message: "Must start with http(s)://"
  validates_presence_of :address
  validates_presence_of :city
  validates_presence_of :state_id
  validates_presence_of :state_abbrev, :message => "State can't be blank."
  validates_presence_of :zip_code
  validates_format_of :zip_code, :with => /\A\d{5}(-\d{4})?\z/, :allow_blank => true
  validates_presence_of :phone
  validates_format_of :phone, :with => /\A\d{3}-\d{3}-\d{4}\z/, :message => 'Phone must look like ###-###-####', :allow_blank => true
  validates_presence_of :organization


  validates_attachment :logo, 
    :size=>{:less_than => 1.megabyte, :message => "Logo must not be bigger than 1 megabyte"},
    :content_type=> { :message => "Logo must be a JPG, GIF, or PNG file",
                      :content_type => ['image/jpeg', 'image/jpg', 'image/pjpeg', 'image/png', 'image/x-png', 'image/gif'] }

  after_validation :make_paperclip_errors_readable

  serialize :survey_question_1, Hash
  serialize :survey_question_2, Hash
  serialize :pixel_tracking_codes, Hash
  serialize :branding_update_request, OpenStruct
  
  # Need to declare attributes for each enabled lang
  RockyConf.enabled_locales.each do |locale|
    unless ['en', 'es'].include?(locale.to_s)
      locale = locale.underscore
      [1,2].each do |num|
        attr_accessor "survey_question_#{num}_#{locale}"
        define_method("survey_question_#{num}_#{locale}") do
          method_missing("survey_question_#{num}_#{locale}")
        end
        define_method("survey_question_#{num}_#{locale}=") do |val|
          method_missing("survey_question_#{num}_#{locale}=", val)
        end
      end
    end
  end
  
  # Need to declare attributes for each email type pixel tracker
  EmailTemplate::EMAIL_TYPES.each do |et|
    attr_accessor "#{et}_pixel_tracking_code"
    define_method("#{et}_pixel_tracking_code") do
      method_missing("#{et}_pixel_tracking_code")
    end
    define_method("#{et}_pixel_tracking_code=") do |val|
      method_missing("#{et}_pixel_tracking_code=", val)
    end
  end
  
  
  include PartnerAssets
  
  scope :government, -> { where(:is_government_partner=>true) }
  scope :standard, -> { where(:is_government_partner=>false) }

  def self.deactivate_stale_partners!
    partners = Partner.inactive.where("active != ?", false).each do |p|
      p.active = false
      p.save(validate: false)
    end
    
    if partners.any?
      AdminMailer.deactivate_partners(partners).deliver
    end
    
  end

  def self.inactive
    date = 90.days.ago
    active_partner_ids = Registrant.where("created_at > ? ", date).pluck(:partner_id)
    active_partner_ids << DEFAULT_ID # Make sure main partner never gets deactivated
    Partner.where("id not in (?) AND (last_login_at < ? OR last_login_at is NULL) AND (current_login_at < ? OR current_login_at IS NULL) AND updated_at < ?", active_partner_ids.uniq, date, date, date)
  end

  def mobile_redirect_disabled
    self.id == 14557 
  end

  def self.find_by_login(login)
    p = find_by_username(login) || find_by_email(login)
    return (p && p.is_government_partner? ? nil : p)
  end

  def primary?
    self.id == DEFAULT_ID
  end
  
  def self.primary_partner
    @@primary_partner ||= self.where(:id=>DEFAULT_ID).first
  end
  def primary_partner
    @primary_partner ||=  self.class.primary_partner
  end
  
  def primary_partner_api_key
    primary_partner ? primary_partner.api_key : nil
  end
  
  def valid_api_key?(key)
    !key.blank? && ((!self.api_key.blank? &&  key == self.api_key) || key == self.primary_partner_api_key)
  end

  def can_be_whitelabeled?
    !primary?
  end

  def custom_logo?
    !primary? && logo.file?
  end


  def registration_stats_state
    sql =<<-"SQL"
      SELECT count(*) as registrations_count, home_state_id FROM `registrants`
      WHERE (status = 'complete' OR status = 'step_5') 
        AND partner_id = #{self.id}
      GROUP BY home_state_id
    SQL
    
    counts = Registrant.connection.select_all(Registrant.send(:sanitize_sql_for_conditions, [sql]))
    
    sum = counts.sum {|row| row["registrations_count"].to_i}
    named_counts = counts.collect do |row|
      state = GeoState[row["home_state_id"].to_i]
      { :state_name => state.nil? ? '' : state.name,
        :registrations_count => (c = row["registrations_count"].to_i),
        :registrations_percentage => c.to_f / sum
      }
    end
    named_counts.sort_by {|r| [-r[:registrations_count], r[:state_name]]}
  end

  #TODO: Fix for other languages
  def registration_stats_race
    counts = Registrant.connection.select_all(<<-"SQL")
      SELECT count(*) as registrations_count, race, locale FROM `registrants`
      WHERE (status = 'complete' OR status = 'step_5') AND partner_id = #{self.id}
      GROUP BY race
    SQL

    # take list of count/race/locale, substitute race/locale to all be en, group again
    en_counts = counts.collect do |crl|
      if crl["locale"] != 'en'
        crl['race'] = Registrant.english_race(crl['locale'], crl['race'])
      end
      crl['race'] = "Unknown" if crl['race'].blank?
      crl
    end
    race_counts = {}
    sum = 0
    en_counts.each do |crl|
      race_counts[crl['race']] ||= 0
      sum += crl['registrations_count'].to_i
      race_counts[crl['race']] +=  crl['registrations_count'].to_i
    end
    named_counts = []
    race_counts.each do |k,v|
      named_counts << {
        :race => k,
        :registrations_count => v,
        :registrations_percentage => v.to_f / sum
      }
    end

    named_counts.sort_by {|r| [-r[:registrations_count], r[:race]]}
  end

  def registration_stats_gender
    counts = Registrant.connection.select_all(<<-"SQL")
      SELECT count(*) as registrations_count, name_title FROM `registrants`
      WHERE (status = 'complete' OR status = 'step_5') AND partner_id = #{self.id}
      GROUP BY name_title
    SQL

    male_titles = RockyConf.enabled_locales.collect { |loc|
     I18n.backend.send(:lookup, loc, "txt.registration.titles.#{Registrant::TITLE_KEYS[0]}") 
    }.flatten.uniq
    
    male_count = female_count = not_specified_count = 0

    counts.each do |row|
      if row["name_title"].blank?
        not_specified_count += row["registrations_count"].to_i
      elsif male_titles.include?(row["name_title"])
        male_count += row["registrations_count"].to_i
      else
        female_count += row["registrations_count"].to_i
      end
    end

    sum = male_count + female_count + not_specified_count
    [ { :gender => "Not Specified",
        :registrations_count => not_specified_count,
        :registrations_percentage => not_specified_count.to_f / sum
      },
      { :gender => "Male",
        :registrations_count => male_count,
        :registrations_percentage => male_count.to_f / sum
      },
      { :gender => "Female",
        :registrations_count => female_count,
        :registrations_percentage => female_count.to_f / sum
      }
    ].sort_by { |r| [ -r[:registrations_count], r[:gender] ] }
  end

  def registration_stats_age
    conditions = "partner_id = ? AND (status = 'complete' OR status = 'step_5') AND (age BETWEEN ? AND ?)"
    stats = {}
    stats[:age_under_18]  = { :count => Registrant.where([conditions, self, 0 , 17]).count }
    stats[:age_18_to_29]  = { :count => Registrant.where([conditions, self, 18, 29]).count }
    stats[:age_30_to_39]  = { :count => Registrant.where([conditions, self, 30, 39]).count }
    stats[:age_40_to_64]  = { :count => Registrant.where([conditions, self, 40, 64]).count }
    stats[:age_65_and_up] = { :count => Registrant.where([conditions, self, 65, 199]).count }
    total_count = stats.inject(0) {|sum, (key,stat)| sum + stat[:count]}
    stats.each { |key, stat| stat[:percentage] = percentage(stat[:count], total_count) }
    stats
  end

  def registration_stats_party
    parties_regs = Registrant.where(partner_id: self.id).where("status = ? OR status = ?", 'complete', 'step_5').group(:official_party_name).count

    total_count = parties_regs.values.sum
    parties_regs.to_a.sort {|a, b| b[1]<=>a[1] }.collect do |row|
      {
        :party=>row[0] || "None (#{Registrant.where(partner_id: self.id).where("status = ? OR status = ?", 'complete', 'step_5').where(finish_with_state: true).count} finished with state)",
        :count=>row[1].to_i,
        :percentage=> percentage(row[1].to_i, total_count)
      }
    end
  end

  def percentage(count, total_count)
    total_count > 0 ? count.to_f / total_count : 0.0
  end

  def registration_stats_completion_date
    conditions = "partner_id = ? AND (status = 'complete' OR status = 'step_5') AND created_at >= ?"
    stats = {}
    stats[:day_count] = {:completed => Registrant.where([conditions, self, 1.day.ago]).count }
    stats[:week_count] = {:completed => Registrant.where([conditions, self, 1.week.ago]).count }
    stats[:month_count] = {:completed => Registrant.where([conditions, self, 1.month.ago]).count }
    stats[:year_to_date_count] =  {:completed => Registrant.where([conditions, self, Time.now.beginning_of_year]).count }
    stats[:year_count] =  {:completed => Registrant.where([conditions, self, 1.year.ago]).count }
    stats[:total_count] = {:completed => Registrant.where(["partner_id = ? AND (status = 'complete' OR status = 'step_5')", self]).count }
    stats[:percent_complete] = {:completed => stats[:total_count][:completed].to_f / Registrant.where(["partner_id = ? AND (status != 'initial')", self]).count }
    
    conditions = "partner_id = ? AND (status = 'complete' OR status = 'step_5') AND created_at >= ? AND pdf_downloaded = ?"

    stats[:day_count][:downloaded] = Registrant.where([conditions, self, 1.day.ago, true]).count
    stats[:week_count][:downloaded] = Registrant.where([conditions, self, 1.week.ago, true]).count
    stats[:month_count][:downloaded] = Registrant.where([conditions, self, 1.month.ago, true]).count
    stats[:year_to_date_count][:downloaded] = Registrant.where([conditions, self, Time.now.beginning_of_year, true]).count
    stats[:year_count][:downloaded] = Registrant.where([conditions, self, 1.year.ago, true]).count
    stats[:total_count][:downloaded] = Registrant.where(["partner_id = ? AND (status = 'complete' OR status = 'step_5') AND pdf_downloaded = ?", self, true]).count
    stats[:percent_complete][:downloaded] = stats[:total_count][:downloaded].to_f / Registrant.where(["partner_id = ? AND (status != 'initial')", self]).count


    
    stats
  end
  
  def registration_stats_finish_with_state_completion_date
    #conditions = "finish_with_state = ? AND partner_id = ? AND status = 'complete' AND created_at >= ?"
    sql =<<-"SQL"
      SELECT count(*) as registrations_count, home_state_id FROM `registrants`
      WHERE status = 'complete'
        AND finish_with_state = ?
        AND partner_id = ?
        AND created_at >= ?
        AND home_state_id in (?)
      GROUP BY home_state_id
    SQL
    
    enabled_state_ids = GeoState.states_with_online_registration.collect{|abbr| GeoState[abbr].id }
    
    stats = {}
    
    [[:day_count, 1.day.ago],
     [:week_count, 1.week.ago],
     [:month_count, 1.month.ago],
     [:year_count, 1.year.ago],
     [:total_count, 1000.years.ago]].each do |range,time|
      counts = Registrant.connection.select_all(Registrant.send(:sanitize_sql_for_conditions, [sql, true, self, time, enabled_state_ids]))
      counts.each do |row|
        state_name = GeoState[row["home_state_id"].to_i].name
        stats[state_name] ||= {:state_name=>state_name}
        stats[state_name][range] = row["registrations_count"].to_i
      end
    end
    stats.to_a.sort {|a,b| a[0]<=>b[0] }.collect{|a| a[1]}
  end

  def ask_for_volunteers?
    RockyConf.sponsor.allow_ask_for_volunteers && read_attribute(:ask_for_volunteers)
  end

  def state_abbrev=(abbrev)
    self.state = GeoState[abbrev]
  end

  def state_abbrev
    state && state.abbreviation
  end
  
  def government_partner_state_abbrev=(abbrev)
    self.government_partner_state = GeoState[abbrev]
  end
  
  def government_partner_state_abbrev
    government_partner_state && government_partner_state.abbreviation
  end

  def government_partner_zip_code_list=(string_list)
    zips = []
    string_list.to_s.split(/[^-\d]/).each do |item|
      zip = item.strip.match(/\A(\d{5}(-\d{4})?)\z/).to_s
      zips << zip unless zip.blank?
    end
    self.government_partner_zip_codes = zips
  end
  
  def government_partner_zip_code_list
    government_partner_zip_codes ? government_partner_zip_codes.join("\n") : nil
  end


  def logo_url
    @logo_url
  end
  
  def logo_url_errors
    @logo_url_errors ||= []
  end
  
  def logo_url=(url)
    @logo_url=url
    if !(url=~/^https?:\/\//)
      logo_url_errors << "Please provide an HTTP(s) url"
    else
      begin
        io = open(url)
        def io.original_filename; base_uri.path.split('/').last; end
        raise 'No Filename' if io.original_filename.blank?
        self.logo = io
      rescue Exception=>e
        # puts e.message
        # raise e
        logo_url_errors << "Could not download #{url} for logo"        
      end
    end
  end
  
  def partner_css_download_url
    @partner_css_download_url
  end
  
  def partner_css_download_contents
    @partner_css_download_contents
  end
  
  def partner_css_download_url_errors
    @partner_css_download_url_errors ||= []
  end
  
  def partner_css_download_url=(url)
    @partner_css_download_url=url
    if !(url=~/^https?:\/\//)
      partner_css_download_url_errors << "Please provide an HTTP(s) url"
    else
      begin
        io = open(url)
        @partner_css_download_contents = io.read
        io.close
      rescue Exception=>e
        puts e.message
        partner_css_download_url_errors << "Could not download #{url} for partner css"        
      end
    end
  end
  
  
  def generate_random_password
    self.password = random_key
    self.password_confirmation = self.password
  end

  def generate_username
    self.username = self.email unless self.username.present?
  end

  def generate_api_key!
    generate_api_key
    save!
  end

  def generate_api_key
    self.api_key = random_key
  end

  def reformat_phone
    if phone.present? && phone_changed?
      digits = phone.gsub(/\D/,'')
      if digits.length == 10
        self.phone = [digits[0..2], digits[3..5], digits[6..9]].join('-')
      end
    end
  end

  def deliver_password_reset_instructions!
    reset_perishable_token!
    Notifier.password_reset_instructions(self).deliver
  end

  def generate_registrants_csv(start_date=nil, end_date=nil)
    conditions = [[]]
    if start_date
      conditions[0] << " registrants.created_at >= ? "
      conditions << start_date
    end
    if end_date
      conditions[0] << " registrants.created_at < ? "
      conditions << end_date + 1.day
    end
    conditions[0] = conditions[0].join(" AND ")

    #preloads
    
    distribute_reads(failover: false) do
      pa_registrants = {}
      StateRegistrants::PARegistrant.where(conditions).joins("LEFT OUTER JOIN registrants on registrants.uid=state_registrants_pa_registrants.registrant_id").where('registrants.partner_id=?',self.id).find_each {|sr| pa_registrants[sr.registrant_id] = sr}
      va_registrants = {}
      StateRegistrants::VARegistrant.where(conditions).joins("LEFT OUTER JOIN registrants on registrants.uid=state_registrants_va_registrants.registrant_id").where('registrants.partner_id=?',self.id).find_each {|sr| va_registrants[sr.registrant_id] = sr}
      
      return CSV.generate do |csv|
        csv << Registrant::CSV_HEADER
        registrants.where(conditions).includes([:home_state, :mailing_state, :partner, :registrant_status]).find_each(:batch_size=>500) do |reg|
          if reg.use_state_flow?
            sr  = nil
            case reg.home_state_abbrev
            when "PA"
              sr = pa_registrants[reg.uid] || StateRegistrants::PARegistrant.new
            when "VA"
              sr = va_registrants[reg.uid] || StateRegistrants::VARegistrant.new
            end
            reg.instance_variable_set(:@existing_state_registrant, sr)
          end
          csv << reg.to_csv_array
        end
      end
    end
  end
  
  SHIFT_REPORT_HEADER = [
    "Date",
    "Unique Shift ID",	
    "Canvasser Name",	
    "Event Zip code",
    "Event Location",	
    "Tablet number",
    "Registrations Collected",
    "Registrations Abandoned",	
    "Registrations Received",
    "# Opt-in to Partner email?",
    "# Opt-in to Partner sms/robocall?",
    "# Registrations w/DL",
    "Registrations w/DL %",
    "# Registrations w/SSN",	
    "Registrations w/SSN %",
    "Canvasser Clock IN (EST)",
    "Canvasser Clock OUT (EST)",
    "Total Shift Hours"
    
  ]
  def generate_grommet_shift_report(start_date=nil, end_date=nil)
    # get the same registrant list
    conditions = [[]]
    if start_date
      conditions[0] << " created_at >= ? "
      conditions << start_date
    end
    if end_date
      conditions[0] << " created_at < ? "
      conditions << end_date + 1.day
    end
    conditions[0] = conditions[0].join(" AND ")
    shift_ids = {}
    distribute_reads(failover: false) do
      registrants.where(conditions).includes([:home_state, :mailing_state, :partner, :registrant_status]).find_each(:batch_size=>500) do |reg|
        shift_ids[reg.tracking_source] ||= {
          registrations: 0,
          email_opt_in: 0,
          sms_opt_in: 0,
          ssn_count: 0,
          dl_count: 0
        } #TrackingEvent.source_tracking_id
        shift_ids[reg.tracking_source][:registrations] += 1
        shift_ids[reg.tracking_source][:email_opt_in] += 1 if reg.partner_opt_in_email?
        shift_ids[reg.tracking_source][:sms_opt_in] += 1 if reg.partner_opt_in_sms?
        shift_ids[reg.tracking_source][:ssn_count] += 1 if reg.has_ssn?
        shift_ids[reg.tracking_source][:dl_count] += 1 if reg.has_state_license?
      end
      clock_ins = TrackingEvent.where(source_tracking_id: shift_ids.keys, tracking_event_name: "pa_canvassing_clock_in")
      clock_outs = {}
      TrackingEvent.where(source_tracking_id: shift_ids.keys, tracking_event_name: "pa_canvassing_clock_out").each do |co|
        clock_outs[co.source_tracking_id] = co
      end
      csvstr = CSV.generate do |csv|
        csv << SHIFT_REPORT_HEADER
        clock_ins.sort{|a,b|( a.tracking_data["clock_in_datetime"] || "") <=> (b.tracking_data["clock_in_datetime"] || "")}.each do |ci|
          co = clock_outs[ci.source_tracking_id]
          tracking_source = ci.source_tracking_id
          counts = shift_ids[tracking_source]
          row = []
          row << eastern_time(ci.tracking_data["clock_in_datetime"])
          row << tracking_source
          row << ci.tracking_data["canvasser_name"]
          row << ci.partner_tracking_id
          row << ci.open_tracking_id
          row << ci.tracking_data["device_id"]
          row << (co ? co.tracking_data["completed_registrations"] : "")
          row << (co ? co.tracking_data["abandoned_registrations"] : "")
          row << counts[:registrations]
          row << counts[:email_opt_in]
          row << counts[:sms_opt_in]
          row << counts[:dl_count]
          row << '%.2f %' % (100.0 * (counts[:dl_count].to_f / counts[:registrations].to_f).to_f)
          row << counts[:ssn_count]
          row << '%.2f %' % (100.0 * (counts[:ssn_count].to_f / counts[:registrations].to_f).to_f)
          row << eastern_time(ci.tracking_data["clock_in_datetime"])
          if co
            row << eastern_time(co.tracking_data["clock_out_datetime"])
            begin
              shift_seconds = (Time.parse(co.tracking_data["clock_out_datetime"]) - Time.parse(ci.tracking_data["clock_in_datetime"])).to_f
              row << shift_seconds / 3600.0
            rescue
              row << ""
            end
          else
            row << ""
            row << ""
          end
          csv << row
        end
      end
      return csvstr
    end
  end
  
  def generate_grommet_registrants_csv(start_date=nil, end_date=nil)
    conditions = [[]]
    if start_date
      conditions[0] << " created_at >= ? "
      conditions << start_date
    end
    if end_date
      conditions[0] << " created_at < ? "
      conditions << end_date + 1.day
    end
    conditions[0] = conditions[0].join(" AND ")

    distribute_reads(failover: false) do
      return CSV.generate do |csv|
        csv << Registrant::GROMMET_CSV_HEADER
        regs = []
        reg_dups = {}
        registrants.where(conditions).includes( [:home_state, :mailing_state, :partner, :registrant_status]).find_each(:batch_size=>500) do |reg|
          if reg.is_grommet?
            key = "#{reg.first_name} #{reg.last_name} #{reg.home_address}"
            reg_dups[key] ||= 0
            reg_dups[key] += 1
            regs << [reg.to_grommet_csv_array, key].flatten
          end
        end
        regs.each do |r|
          key = r.pop
          if reg_dups[key] > 1
            r.insert(1, "true")
          else
            r.insert(1, "false")
          end
          csv << r
        end
      end
    end
  end
  
  
  def generate_registrants_csv_async(start_date=nil, end_date=nil)
    self.csv_ready=false
    self.save!
    action = Delayed::PerformableMethod.new(self, :generate_registrants_csv_file, [start_date, end_date])
    Delayed::Job.enqueue(action, CSV_GENERATION_PRIORITY, Time.now)
  end
  
  def generate_grommet_registrants_csv_async(start_date=nil, end_date=nil)
    self.grommet_csv_ready=false
    self.save!
    action = Delayed::PerformableMethod.new(self, :generate_grommet_registrants_csv_file, [start_date, end_date])
    Delayed::Job.enqueue(action, CSV_GENERATION_PRIORITY, Time.now)
  end
  
  def csv_url
    "https://s3-us-west-2.amazonaws.com/rocky-reports#{Rails.env.production? ? '' : "-#{Rails.env}"}/#{File.join(self.id.to_s, self.csv_file_name)}"    
  end
  def grommet_csv_url
    "https://s3-us-west-2.amazonaws.com/rocky-reports#{Rails.env.production? ? '' : "-#{Rails.env}"}/#{File.join(self.id.to_s, self.grommet_csv_file_name.to_s)}"    
  end
  
  def generate_registrants_csv_file(start_date=nil, end_date = nil)
    time_stamp = end_date || Time.now
    self.csv_file_name = self.generate_csv_file_name(time_stamp, start_date)
    file = File.open(csv_file_path, "w")
    file.write generate_registrants_csv(start_date, end_date).force_encoding 'utf-8'
    file.close
    # UPLOAD TO S3
    upload_registrants_csv_file
    
    File.delete(csv_file_path)
    
    self.csv_ready = true
    self.save!
  end
  
  def generate_grommet_registrants_csv_file(start_date=nil, end_date = nil)
    time_stamp = end_date || Time.now
    self.grommet_csv_file_name = self.generate_grommet_csv_file_name(time_stamp, start_date)
    file = File.open(grommet_csv_file_path, "w")
    file.write generate_grommet_registrants_csv(start_date, end_date).force_encoding 'utf-8'
    file.close
    # UPLOAD TO S3
    upload_grommet_registrants_csv_file
    
    File.delete(grommet_csv_file_path)
    
    self.grommet_csv_ready = true
    self.save!
  end
  
  def upload_registrants_csv_file
    upload_csv_file(csv_file_path, self.csv_file_name)
  end
  
  def upload_grommet_registrants_csv_file
    upload_csv_file(grommet_csv_file_path, self.grommet_csv_file_name)
  end
  
  def upload_csv_file(file_path, file_name)
    connection = Fog::Storage.new({
      :provider                 => 'AWS',
      :aws_access_key_id        => ENV['PDF_AWS_ACCESS_KEY_ID'],
      :aws_secret_access_key    => ENV['PDF_AWS_SECRET_ACCESS_KEY'],
      :region                   => 'us-west-2'
    })
    
    bucket_name = "rocky-reports#{Rails.env.production? ? '' : "-#{Rails.env}"}"
    directory = connection.directories.get(bucket_name)
    file = directory.files.create(
      :key    => File.join(self.id.to_s, file_name),
      :body   => File.open(file_path, "r").read,
      :content_type => "text/csv",
      :encryption => 'AES256', #Make sure its encrypted on their own hard drives
      :public => true
    )  
  end
  
  def delete_registrants_csv_file(file_name)
    if File.exists?(csv_file_path(file_name))
      File.delete(csv_file_path(file_name))
    end
  end
  
  def generate_csv_file_name(end_time, start_date=nil)
    obfuscate = Digest::SHA1.hexdigest( "#{Time.now.usec} -- #{rand(1000000)}" )
    "csv-#{obfuscate}-#{start_date ? "#{start_date.strftime('%Y%m%d')}-" : '' }#{end_time.strftime('%Y%m%d')}.csv"
  end

  def generate_grommet_csv_file_name(end_time, start_date=nil)
    obfuscate = Digest::SHA1.hexdigest( "#{Time.now.usec} -- #{rand(1000000)}" )
    "csv-grommet-#{obfuscate}-#{start_date ? "#{start_date.strftime('%Y%m%d')}-" : '' }#{end_time.strftime('%Y%m%d')}.csv"
  end

  
  def csv_file_path(file_name = nil)
    File.join(csv_path, file_name || self.csv_file_name)
  end
  def grommet_csv_file_path(file_name = nil)
    File.join(csv_path, file_name || self.grommet_csv_file_name)
  end
  def csv_path
    path = File.join(Rails.root, "csv", self.id.to_s)
    FileUtils.mkdir_p(path)
    path
  end
  

  def widget_image_name
    WIDGET_IMAGES.detect { |widget| widget[0] == self.widget_image }[1]
  end

  def widget_image_name=(name)
    self.widget_image = WIDGET_IMAGES.detect { |widget| widget[1] == name }[0]
  end

  def set_default_widget_image
    self.widget_image_name = DEFAULT_WIDGET_IMAGE_NAME if self.widget_image.blank?
  end

  def make_paperclip_errors_readable
    if Array(errors[:logo]).any? {|e| e =~ /not recognized by the 'identify' command/}
      errors.clear
      errors.add(:logo, "logo must be an image file")
    end
  end

    

  def self.add_whitelabel(partner_id, app_css, reg_css, part_css)
    app_css = File.open(File.expand_path(app_css), "r")
    reg_css = File.open(File.expand_path(reg_css), "r")
    part_css = File.open(File.expand_path(part_css), "r")

    partner = nil
    begin
      partner = Partner.find(partner_id)
    rescue
    end

    raise "Partner with id '#{partner_id}' was not found." unless partner

    if partner.primary?
      raise "You can't whitelabel the primary partner."
    end

    if partner.whitelabeled
      raise "Partner '#{partner_id}' is already whitelabeled. Try running 'rake partner:upload_assets #{partner_id} #{app_css} #{reg_css}'"
    end


    if partner.any_css_present?
      raise "Partner '#{partner_id}' has assets. Try running 'rake partner:enable_whitelabel #{partner_id}'"
    end

    paf = PartnerAssetsFolder.new(partner)

    paf.update_css("application", app_css) if File.exists?(app_css)
    paf.update_css("registration", reg_css) if File.exists?(reg_css)
    paf.update_css("partner", part_css) if File.exists?(part_css)

    copy_success = partner.application_css_present? == File.exists?(app_css)
    copy_success = copy_success && partner.registration_css_present? == File.exists?(reg_css)
    copy_success = copy_success && partner.partner_css_present? == File.exists?(part_css)
    
    raise "Error copying css to partner directory '#{partner.assets_path}'" unless copy_success

    if copy_success
      partner.whitelabeled= true
      partner.save!
      return "Partner '#{partner_id}' has been whitelabeled. Place all asset files in\n#{partner.assets_path}"
    end

  end
  
  def default_pixel_tracking_code(kind)
    self.class.default_pixel_tracking_code(kind)
  end
  
  def self.default_pixel_tracking_code(kind)
    ea = kind
    ea = 'state_integrated' if ea == 'thank_you_external'
    ea = 'chase' if ea == 'chaser'
    return "<img src=\"http://www.google-analytics.com/collect?v=1&tid=UA-1913089-11&cid=<%= @registrant.uid %>&t=event&ec=email&ea=#{ea}_open&el=<%= @registrant.partner_id %>&cs=reminder&cm=email&cn=ovr_email_opens&cm1=1&ul=<%= @registrant.locale %>\" />"
    
  end
  
  def from_email_verified?
    if self.from_email.blank?
      return false
    end
       # if verified and verification happend after 1 hour ago
    if self.from_email_verified_at && self.from_email_verified_at > 1.hour.ago
      return true
    else 
      # if never checked OR checked before 5 minutes ago 
      if self.from_email_verification_checked_at.nil? || self.from_email_verification_checked_at < 5.minutes.ago
        return self.check_from_email_verification
      else
        return false
      end
    end
  end
  
protected

  def detect_from_email_change
    if self.from_email_changed?
      self.from_email_verified_at = nil
    end
  end

  def check_from_email_verification
    ses = Aws::SES::Client.new(
          region: 'us-west-2',
          access_key_id: ENV['SQS_AWS_ACCESS_KEY_ID'],
          secret_access_key: ENV['SQS_AWS_SECRET_ACCESS_KEY'])
    resp = ses.get_identity_verification_attributes({
        identities: [self.from_email], # required
    })
    if resp.verification_attributes[self.from_email].blank?
      ses.verify_email_identity({email_address: self.from_email})
      return false
    end
    verified = resp.verification_attributes[self.from_email].verification_status == "Success"
    if verified
      self.from_email_verified_at= DateTime.now
      self.save
      return true
    else
      return false
    end
  rescue
    return false
  ensure
    self.from_email_verification_checked_at = DateTime.now
    self.save
  end


  def method_missing(method_name, *args, &block)
    if method_name =~ /\Asurvey_question_(\d+)_([^=]+)(=?)\z/
      question_num = $1
      locale = $2.to_s.underscore
      setter = !($3.blank?)
      if setter 
        if args.size == 1
          current = self.send("survey_question_#{question_num}")
          current[locale] = args[0]
          self.send("survey_question_#{question_num}=",current)
        else
          raise ArgumentError.new("Setting a survey question must have a value")
        end
      else
        return self.send("survey_question_#{question_num}")[locale]
      end
    elsif method_name =~ /\A(.+)_pixel_tracking_code(=?)\z/
      email_type = $1.to_s
      setter = !($2.blank?)
      if setter
        if args.size == 1
          self.pixel_tracking_codes[email_type] = args[0]
        else
          raise ArgumentError.new("Setting a pixel tracking code must have 1 argument")
        end
      else
        return self.pixel_tracking_codes[email_type]
      end
    else
      return super 
    end
  end

  def check_valid_logo_url
    logo_url_errors.each do |message|
      self.errors.add(:logo_image_URL, message)
    end
  end
  
  def check_valid_partner_css_download_url
    partner_css_download_url_errors.each do |message|
      self.errors.add(:partner_css_download_URL, message)
    end
  end
  
  def write_partner_css_download_contents
    if !partner_css_download_contents.blank?
      PartnerAssetsFolder.new(self).write_css("partner", partner_css_download_contents)
    end
  end
  
  def government_partner_zip_specification
    if self.is_government_partner? 
      [[self.government_partner_state.nil? && self.government_partner_zip_codes.blank?, 
            "Either a State or a list of zip codes must be specified for a government partner"],
       [!self.government_partner_state.nil? && !self.government_partner_zip_codes.blank?, 
            "Only one of State or zip code list can be specified for a government partner"]].each do |causes_error, message|
        if causes_error
          [:government_partner_state_abbrev, :government_partner_zip_code_list].each do |field|
            errors.add(field, message)
          end
        end         
      end
    end
  end

  def check_valid_registration_instructions_url_format
    if !registration_instructions_url.blank?
      if !(registration_instructions_url =~ /<STATE>/)
        errors.add(:registration_instructions_url, "must include <STATE> substitution variable")
      end
      if !(registration_instructions_url =~ /<LOCALE>/)
        errors.add(:registration_instructions_url, "must include <LOCALE> substitution variable")
      end
    end
    return true
  end
  
  def random_key
    Digest::SHA1.hexdigest([Time.now, (1..10).map { rand.to_s}].join('--'))
  end

end