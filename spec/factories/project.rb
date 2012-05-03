Factory.define :fixed_cost, :class=>Project do |fc|
  fc.issue_custom_field_ids []
  fc.tracker_ids ["1", "2", "3", "4", "5", ""]
  fc.inherit "0"
  fc.name "FC Project"
  fc.description "Test"
  fc.homepage ""
  fc.show_update_option "0"
  fc.acctg_type "10"
  fc.custom_field_values Hash["18"=>"Fixed Cost", "15"=>"Development", "20"=>"0", "24"=>"Enterprise Project"]
  fc.is_public "1"
  fc.identifier "fc123"
end

Factory.define :admin_proj, :class=>Project do |ap|
  ap.issue_custom_field_ids []
  ap.tracker_ids ["1", "2", "3", "4", "5", ""]
  ap.inherit "0"
  ap.name "Admin Project"
  ap.description "Test"
  ap.homepage ""
  ap.show_update_option "0"
  ap.acctg_type "10"
  ap.custom_field_values Hash["18"=>"", "15"=>"Admin", "20"=>"0", "24"=>"N/A"]
  ap.is_public "1"
  ap.identifier "non-proj123"
end
