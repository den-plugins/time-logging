Factory.define :test_user, :class=>User do |bt|
  bt.login "rspec-tester"
  bt.custom_field_values Hash["25"=>"", "23"=>"Regular", "22"=>"Exist", "21"=>""]
  bt.location "Manila"
  bt.skill "RoR"
  bt.mail "rt@yahoo.com"
  bt.firstname "Rspec"
  bt.auth_source_id nil
  bt.language "en"
  bt.is_engineering "1"
  bt.admin "1"
  bt.lastname "Tester"
  bt.password "123qwe"
end
