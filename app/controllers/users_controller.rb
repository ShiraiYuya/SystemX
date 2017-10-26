require 'roo-xls'

class UsersController < ApplicationController
  def index
	
	@time = Time.zone.now
	date = Time.zone.today
	#date = date.ago(4.day)
	wday = date.wday
	
	#csvを受け取って出荷量（f,z,other別）をDBとpythonに渡す
	if params[:file] != nil
		p params[:file].path
		xls = Roo::Excel.new(params[:file].path)
		xls.default_sheet = '出荷台帳（入力順）'		
		shipdate = Date.strptime(xls.cell(2,3).encode("UTF-8"),'%m/%d ');
		swday = shipdate.wday
		
		@f = 0
		@zenran = 0
		@other = 0

		for i in 4..xls.last_row do
			if xls.cell(i, 4) != nil
				product = xls.cell(i, 4).encode("UTF-8")
				size = xls.cell(i, 6).tr!("０-９", "0-9").to_i
				num = xls.cell(i, 8).tr!("０-９", "0-9").to_i

				if product=="Ｆ"
					@f += size * num
				elsif product=="全卵"
					@zenran += size * num 
				else
					@other += size * num
				end
				
			end
		end
		@f /= 1000.0
		@zenran /= 1000.0
		@other /= 1000.0 
		
		#ここでDBに登録
		if Amount.exists?(:date => shipdate)
			amount = Amount.find_by(date: shipdate)
			amount.update(f_ship: @f,z_ship: @zenran, other_ship: @other)
		elsif
			amount = Amount.new(date: shipdate,f_ship: @f,z_ship: @zenran, other_ship: @other)
			amount.save
		end
		
		#ここでpythonとやりとり
		
		#受け取りは各日の予測出荷量（f,z,other別）
		f_py = [0,1000,400,350,450,800]
		z_py = [0,600,300,400,400,700]
		other_py = [0,600,600,650,700,900]
		
		#shipdate~土までに作る総量sum（f,z,other別），平均aver
		amount = Amount.find_by(date: shipdate)
		f_sum = @f - amount.f_stored
		z_sum = @zenran - amount.z_stored
		other_sum = @other
		for i in (swday+1)..6 do
			f_sum += f_py[i-1]
			z_sum += z_py[i-1]
			other_sum += other_py[i-1]
		end
		sum = f_sum + z_sum + other_sum
		aver = (sum / (7 - swday)).to_i		
		
		#shipdateのstore登録（f,z別）
		store = aver - (@f - amount.f_stored) - (@zenran-amount.z_stored) - @other
		store = 0 if store<0
		f_store = (-z_sum*(amount.f_ship-amount.f_stored)+f_sum*(amount.z_ship-amount.z_stored+store))/(z_sum+f_sum)
		f_store = [[f_store,store].min, 0].max
		z_store = store - f_store
		amount.update(f_store: f_store, z_store: z_store)
		
		sum = sum - (amount.f_ship - amount.f_stored + amount.f_store) - (amount.z_ship - amount.z_stored + amount.z_store) - amount.other_ship
		f_sum = f_sum - (amount.f_ship - amount.f_stored + amount.f_store)
		z_sum = z_sum - (amount.z_ship - amount.z_stored + amount.z_store)
		
		#shipdateの次の日以降のpred,stored,store登録
		for i in (swday+1)..6 do
			aver = sum / (7 - i)
			if Amount.exists?(:date => shipdate.ago(swday.day).since(i.day))
				amount = Amount.find_by(date: shipdate.ago(swday.day).since(i.day))
				amount.update(f_stored: f_store, z_stored: z_store, f_pred: f_py[i-1], z_pred: z_py[i-1], other_pred: other_py[i-1])
				
			elsif
				amount = Amount.new(date: shipdate.ago(swday.day).since(i.day),f_pred: f_py[i-1], z_pred: z_py[i-1], other_pred: other_py[i-1],f_stored: f_store, z_stored: z_store)
				amount.save
			end
			store = aver - (amount.f_pred + amount.z_pred + amount.other_pred - store)
			store = 0 if store<0
			f_store = (-z_sum*(amount.f_pred-amount.f_stored)+f_sum*(amount.z_pred-amount.z_stored+store))/(z_sum+f_sum)
			f_store = [[f_store,store].min, 0].max
			z_store = store - f_store
			amount.update(f_store: f_store, z_store: z_store)
			sum = sum - (amount.f_pred - amount.f_stored + amount.f_store) - (amount.z_pred - amount.z_stored + amount.z_store) - amount.other_pred
			f_sum = f_sum - (amount.f_ship - amount.f_stored + amount.f_store)
			z_sum = z_sum - (amount.z_ship - amount.z_stored + amount.z_store)
		end
	end
	#ここまでcsv受け取り時の処理
	
	
	#本日のデータ取得
	if Amount.exists?(:date => date)
		@today = Amount.find_by(date: date)
	elsif
		amount = Amount.new(date: date)
		amount.save
		@today = amount
	end
	
	wdaylist = ["Mon","Tue","Wed","Thu","Fri","Sat"]

	f_ship_list = []
	f_make_list = [] #ship-stored
	f_makepred_list = [] #pred-stored
	f_store_list = []
	f_pred_list = []
	z_ship_list = []
	z_make_list = []
	z_makepred_list = []
	z_store_list = []
	z_pred_list = []
	other_ship_list = []
	other_pred_list = []
	

	for i in 1..wday do
		if Amount.exists?(:date => date.ago(wday.day).since(i.day))
			amount = Amount.find_by(date: date.ago(wday.day).since(i.day))
			f_ship_list.push([wdaylist[i-1],amount.f_ship]) if amount.f_ship!=0
			z_ship_list.push([wdaylist[i-1],amount.z_ship]) if amount.z_ship!=0
			other_ship_list.push([wdaylist[i-1],amount.other_ship]) if amount.other_ship!=0
			f_make_list.push([wdaylist[i-1],amount.f_ship-amount.f_stored]) if amount.f_ship-amount.f_stored>0
			z_make_list.push([wdaylist[i-1],amount.z_ship-amount.z_stored]) if amount.z_ship-amount.z_stored>0
			
		end
	end
	
	for i in (wday+1)..6 do
		if Amount.exists?(:date => date.ago(wday.day).since(i.day))
			amount = Amount.find_by(date: date.ago(wday.day).since(i.day))
			f_pred_list.push([wdaylist[i-1],amount.f_pred]) if amount.f_pred!=0
			z_pred_list.push([wdaylist[i-1],amount.z_pred]) if amount.z_pred!=0
			other_pred_list.push([wdaylist[i-1],amount.other_pred]) if amount.other_pred!=0
			f_makepred_list.push([wdaylist[i-1],amount.f_pred-amount.f_stored]) if amount.f_pred-amount.f_stored>0
			z_makepred_list.push([wdaylist[i-1],amount.z_pred-amount.z_stored]) if amount.z_pred-amount.z_stored>0
		end
	end
	
	for i in 1..6 do
		if Amount.exists?(:date => date.ago(wday.day).since(i.day))
			amount = Amount.find_by(date: date.ago(wday.day).since(i.day))
			f_store_list.push([wdaylist[i-1],amount.f_store]) if amount.f_store!=0
			z_store_list.push([wdaylist[i-1],amount.z_store]) if amount.z_store!=0
		end
	end
	
	@chart_data = [
	{name:"None",data:[["Mon",0],["Tue",0],["Wed",0],["Thu",0],["Fri",0],["Sat",0]]},
	{name:"F確定",data:f_make_list},
	{name:"全卵確定",data:z_make_list},
	{name:"その他確定",data:other_ship_list},
	{name:"F予測",data:f_makepred_list},
	{name:"全卵予測",data:z_makepred_list},
	{name:"その他予測",data:other_pred_list},
	{name:"F作り置き",data:f_store_list},
	{name:"全卵作り置き",data:z_store_list}
	]
	
	@chart_data2 = [
	{name:"None",data:[["Mon",0],["Tue",0],["Wed",0],["Thu",0],["Fri",0],["Sat",0]]},
	{name:"F確定",data:f_ship_list},
	{name:"全卵確定",data:z_ship_list},
	{name:"その他確定",data:other_ship_list},
	{name:"F予測",data:f_pred_list},
	{name:"全卵予測",data:z_pred_list},
	{name:"その他予測",data:other_pred_list}
	]
  end

  def conf
	@products = Product.where(company: 1)
	@materials = Material.where(company: 1)
  end

  def stock
  end
  
end
