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
class PartnerDetails

  def initialize(partner)
    @p = partner
  end

  def name
    @p.name
  end

  def organization
    @p.organization
  end

  def email
    @p.email
  end

  def whitelabel_status
    @p.whitelabeled? ? 'Yes' : 'No'
  end

  def enabled_for_grommet_status
    @p.enabled_for_grommet? ? 'Yes' : 'No'
  end


  def assets_status
    [ [ "application.css",          pm(@p.application_css_present?) ],
      [ "registration.css",         pm(@p.registration_css_present?) ],
      [ "confirmation.en.html.erb", pm(EmailTemplate.present?(@p, 'confirmation.en')) ],
      [ "confirmation.es.html.erb", pm(EmailTemplate.present?(@p, 'confirmation.es')) ],
      [ "reminder.en.html.erb",     pm(EmailTemplate.present?(@p, 'reminder.en')) ],
      [ "reminder.es.html.erb",     pm(EmailTemplate.present?(@p, 'reminder.es')) ] ]
  end

  private

  def pm(v)
    v ? 'present' : 'missing'
  end
end
