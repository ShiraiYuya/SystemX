require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get users_index_url
    assert_response :success
  end

  test "should get config" do
    get users_config_url
    assert_response :success
  end

  test "should get stock" do
    get users_stock_url
    assert_response :success
  end

end
