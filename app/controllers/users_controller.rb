class UsersController < ApplicationController
  def index
	@chart_data = [
	{name:"F",data:[["Mon",10],["Tue",20],["Wed",10],["Thu",20],["Fri",10],["Sat",20]]},
	{name:"全卵",data:[["Mon",10],["Tue",20],["Wed",10],["Thu",40],["Fri",10],["Sat",20]]},
	{name:"その他",data:[["Mon",10],["Tue",20],["Wed",10],["Thu",20],["Fri",10],["Sat",20]]},
	{name:"F作り置き",data:[["Mon",10],["Tue",20],["Wed",10],["Thu",20],["Fri",10],["Sat",20]]},
	{name:"全卵作り置き",data:[["Mon",10],["Tue",20],["Wed",10],["Thu",20],["Fri",10],["Sat",20]]}
	]
  end

  def conf
	@products = Product.where(company: 1)
	@materials = Material.where(company: 1)
  end

  def stock
  end
end
