feature "Switch Organisation" do
  include_context "admin"

  it "has the expected content" do
    click_link "Switch organisation"

    expect(page).to have_xpath "//h1[text()='Switch organisation']"
  end

  it "switches location" do
    click_link "Switch organisation"
    click_button "Automated Test 2"

    expect(page).to have_xpath "//span[contains(@class,'govuk-service-navigation__service-name')]/strong[text()='Automated Test 2']"
  end
end
