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
require File.expand_path(File.join(File.dirname(__FILE__), "..", "support", "paths"))

# Commonly used webrat steps
# http://github.com/brynary/webrat

When /^show the page$/ do
  save_and_open_page
end


Given /^I am on (.+)$/ do |page_name|
  visit path_to(page_name)
end

When /^I go to (.+)$/ do |page_name|
  visit path_to(page_name)
  #raise page.body.to_s
end

When /^I press "([^\"]*)"$/ do |button|
  click_button(button)
end

When /^I follow "([^\"]*)"$/ do |link|
  #raise page.body.to_s
  click_link(link)
end

When /^I fill in "([^\"]*)" with "([^\"]*)"$/ do |field, value|
  fill_in(field, :with => value) 
end

When /^I select "([^\"]*)" from "([^\"]*)"$/ do |value, field|
  select(value, :from => field) 
end

# Use this step in conjunction with Rail's datetime_select helper. For example:
# When I select "December 25, 2008 10:00" as the date and time 
When /^I select "([^\"]*)" as the date and time$/ do |time|
  select_datetime(time)
end

# Use this step when using multiple datetime_select helpers on a page or 
# you want to specify which datetime to select. Given the following view:
#   <%= f.label :preferred %><br />
#   <%= f.datetime_select :preferred %>
#   <%= f.label :alternative %><br />
#   <%= f.datetime_select :alternative %>
# The following steps would fill out the form:
# When I select "November 23, 2004 11:20" as the "Preferred" date and time
# And I select "November 25, 2004 10:30" as the "Alternative" date and time
When /^I select "([^\"]*)" as the "([^\"]*)" date and time$/ do |datetime, datetime_label|
  select_datetime(datetime, :from => datetime_label)
end

# Use this step in conjunction with Rail's time_select helper. For example:
# When I select "2:20PM" as the time
# Note: Rail's default time helper provides 24-hour time-- not 12 hour time. Webrat
# will convert the 2:20PM to 14:20 and then select it. 
When /^I select "([^\"]*)" as the time$/ do |time|
  select_time(time)
end

# Use this step when using multiple time_select helpers on a page or you want to
# specify the name of the time on the form.  For example:
# When I select "7:30AM" as the "Gym" time
When /^I select "([^\"]*)" as the "([^\"]*)" time$/ do |time, time_label|
  select_time(time, :from => time_label)
end

# Use this step in conjunction with Rail's date_select helper.  For example:
# When I select "February 20, 1981" as the date
When /^I select "([^\"]*)" as the date$/ do |date|
  select_date(date)
end

# Use this step when using multiple date_select helpers on one page or
# you want to specify the name of the date on the form. For example:
# When I select "April 26, 1982" as the "Date of Birth" date
When /^I select "([^\"]*)" as the "([^\"]*)" date$/ do |date, date_label|
  select_date(date, :from => date_label)
end

When /^I check "([^\"]*)"$/ do |field|
  check(field) 
end

When /^I uncheck "([^\"]*)"$/ do |field|
  #raise @registrant.inspect
  #raise page.body.to_s
  uncheck(field) 
end

When /^I choose "([^\"]*)"$/ do |field|
  choose(field)
end

When /^I attach the file at "([^\"]*)" to "([^\"]*)"$/ do |path, field|
  attach_file(field, path)
end

Then /^I should see "([^\"]*)"$/ do |text|
  page.should have_content(text)
end



Then /^I should not see "([^\"]*)"$/ do |text|
  page.should_not have_content(text)
end

Then /^the "([^\"]*)" field should contain "([^\"]*)"$/ do |field, value|
  field_labeled(field).value.should =~ /#{value}/
end

Then /^the "([^\"]*)" field should not contain "([^\"]*)"$/ do |field, value|
  field_labeled(field).value.should_not =~ /#{value}/
end
    
Then /^the "([^\"]*)" checkbox should be checked$/ do |label|
  field_labeled(label).should be_checked
end

Then /^the "([^\"]*)" checkbox should not be checked$/ do |label|
  field_labeled(label).should_not be_checked
end


Then /^I should see a field for "([^\"]*)"$/ do |label|
  page.should have_field(label)
end

Then /^I should not see a field for "([^\"]*)"$/ do |label|
  page.should_not have_field(label)
end


Then /^I should see a checkbox for "([^\"]*)"$/ do |label|
  # raise @registrant.any_ask_for_volunteers?.to_s
  # raise page.body.to_s
  page.should have_checkbox(label)
end

Then /^I should not see a checkbox for "([^\"]*)"$/ do |label|
  page.should_not have_checkbox(label)
end

Then /^I should see a button for "([^\"]*)"$/ do |label|
  page.should have_button(label)  
  # button= field_by_xpath("//button[span[text()=\"#{label}\"]]")
  # button.should be_a(Webrat::ButtonField)
end

Then /^I should not see a button for "([^\"]*)"$/ do |label|
  page.should_not have_button(label)  
  #field_by_xpath("//button[span[text()=\"#{label}\"]]").should be_nil
end


Then /^I should see a disabled button for "([^\"]*)"$/ do |label|
  button= field_by_xpath("//button[span[text()=\"#{label}\"]]")
  button.should be_disabled
end

Then /^I should see an enabled button for "([^\"]*)"$/ do |label|
  button= field_by_xpath("//button[span[text()=\"#{label}\"]]")
  button.should_not be_disabled
end

Then /^I should see a link for "([^\"]*)"$/ do |text|
  page.should have_link(text)
  #field_by_xpath("//a[text()='#{text}']").should be
end

Then /^I should( not)? see an href to "([^\"]*)"$/ do |should_not, url|
  if should_not
    page.should_not have_link(nil, href: url)
  else
    page.should have_link(nil, href: url)
  end
end


Then /^I should be on (.+)$/ do |page_name|
  URI.parse(current_url).path.should == path_to(page_name)
end
