require 'roo-xls'

class UsersController < ApplicationController
  def index
	
	#csvを受け取って出荷量（f,z,other別）をDBとpythonに渡す
	if params[:file] != nil
	
		#入力エクセルの前処理
		xls = Roo::Excel.new(params[:file].path)
		xls.default_sheet = '出荷台帳（入力順）'		
		shipdate = Date.strptime(xls.cell(2,3).encode("UTF-8"),'%m/%d ');
		swday = shipdate.wday
		
		#出荷量の算出
		f,zenran,other = 0,0,0
		for i in 4..xls.last_row do
			if xls.cell(i, 4) != nil
				product = xls.cell(i, 4).encode("UTF-8")
				size = xls.cell(i, 6).tr!("０-９", "0-9").to_i
				num = xls.cell(i, 8).tr!("０-９", "0-9").to_i

				if product=="Ｆ"
					f += size * num
				elsif product=="全卵"
					zenran += size * num 
				else
					other += size * num
				end				
			end
		end
		#kg変換
		f /= 1000
		zenran /= 1000
		other /= 1000 
		
		#ここでDBに登録
		amount = Amount.find_or_create_by(date: shipdate)
		amount.update(f_ship: f,z_ship: zenran, other_ship: other)
		
		
		#ここでpythonとやりとり
		
		#受け取りは各日の予測出荷量（f,z,other別）：月から日まで
		f_py = [0,400,400,350,450,800,0]
		z_py = [0,350,300,400,400,700,0]
		other_py = [0,600,600,650,700,900,0]
		f_nw_py = [450,400,400,350,450,800,0]
		z_nw_py = [400,350,300,400,400,700,0]
		other_nw_py = [700,600,600,650,700,900,0]
		#ここでshipが確定しているものがあれば置き換える
		
		
		#shipdate~土までに作る総量sum（f,z,other別），平均averを算出
		amount = Amount.find_by(date: shipdate)#一応再定義
		f_sum = amount.f_ship - amount.f_stored
		z_sum = amount.z_ship - amount.z_stored
		other_sum = amount.other_ship
		for i in swday..5 do
			f_sum += f_py[i]
			z_sum += z_py[i]
			other_sum += other_py[i]
		end
		sum = f_sum + z_sum + other_sum
		aver = (sum / (7 - swday)).to_i		
		
		#shipdateのstore登録（f,z別）
		store = [aver - (amount.f_ship - amount.f_stored) - (amount.z_ship - amount.z_stored) - amount.other_ship, 0].max
		f_store = (-z_sum * (amount.f_ship - amount.f_stored) + f_sum * (amount.z_ship - amount.z_stored + store)) / (z_sum + f_sum)
		f_store = [[f_store,store,f_py[swday]].min, 0].max
		z_store = [store - f_store, z_py[swday]].min
		amount.update(f_store: f_store, z_store: z_store)
		
		sum -= (amount.f_ship - amount.f_stored + amount.f_store) + (amount.z_ship - amount.z_stored + amount.z_store) + amount.other_ship
		f_sum -= amount.f_ship - amount.f_stored + amount.f_store
		z_sum -= amount.z_ship - amount.z_stored + amount.z_store
		
		#shipdateの次の日以降のpred,stored,store登録
		for i in (swday+1)..6 do		
			aver = sum / (7 - i)
			amount = Amount.find_or_create_by(date: shipdate.ago(swday.day).since(i.day))
			amount.update(f_stored: f_store, z_stored: z_store, f_pred: f_py[i-1] , z_pred: z_py[i-1], other_pred: other_py[i-1])
			
			store = [aver - (f_py[i-1] + z_py[i-1] + other_py[i-1] - store), 0].max
			f_store = (-z_sum * (f_py[i-1] - f_store) + f_sum * (z_py[i-1] - z_store + store) ) / (z_sum + f_sum)
			f_store = [[f_store,store,f_py[i]].min, 0].max
			z_store = [store - f_store, z_py[i]].min
			
			amount.update(f_store: f_store, z_store: z_store)
			
			sum -= (amount.f_pred - amount.f_stored + amount.f_store) + (amount.z_pred - amount.z_stored + amount.z_store) + amount.other_pred
			f_sum -= amount.f_pred - amount.f_stored + amount.f_store
			z_sum -= amount.z_pred - amount.z_stored + amount.z_store
		end
		
		#翌週月~土までに作る総量sum（f,z,other別），平均averを算出
		f_sum = f_nw_py.sum
		z_sum = z_nw_py.sum
		other_sum = other_nw_py.sum
		sum = f_sum + z_sum + other_sum
		f_store = 0
		z_store = 0
		store = 0
		
		#翌週各日のpred,stored,store登録
		for i in 1..6 do		
			aver = sum / (7 - i)
			amount = Amount.find_or_create_by(date: shipdate.ago(swday.day).since((7+i).day))
			amount.update(f_stored: f_store, z_stored: z_store, f_pred: f_nw_py[i-1] , z_pred: z_nw_py[i-1], other_pred: other_nw_py[i-1])
			
			store = [aver - (f_nw_py[i-1] + z_nw_py[i-1] + other_nw_py[i-1] - store), 0].max
			f_store = (-z_sum * (f_nw_py[i-1] - f_store) + f_sum * (z_nw_py[i-1] - z_store + store) ) / (z_sum + f_sum)
			f_store = [[f_store,store,f_nw_py[i]].min, 0].max
			z_store = [store - f_store, z_nw_py[i]].min
			
			amount.update(f_store: f_store, z_store: z_store)
			
			sum -= (amount.f_pred - amount.f_stored + amount.f_store) + (amount.z_pred - amount.z_stored + amount.z_store) + amount.other_pred
			f_sum -= amount.f_pred - amount.f_stored + amount.f_store
			z_sum -= amount.z_pred - amount.z_stored + amount.z_store
		end
	end
	#ここまでcsv受け取り時の処理
	
	
	#本日のデータ取得
	@time = Time.zone.now
	date = Time.zone.today
	date = date.ago(0.day)
	wday = date.wday
	@sunday = (wday == 0)
	
	#table用データ
	jwdaylist = ["月曜","火曜","水曜","木曜","金曜","土曜"]
	@table_display = true
	for i in 1..wday do
		if Amount.exists?(:date => date.ago(wday.day).since(i.day))
			amount = Amount.find_by(date: date.ago(wday.day).since(i.day))
			@today = amount if i==wday
			next if amount.f_ship!=0
		end
		@noexcelmsg = jwdaylist[i-1]+"分のエクセルファイルを入力してください．"
		@noexcelmsg = "本日分のエクセルファイルを入力してください．" if i==wday
		@table_display = false
		break	
	end
	if @sunday
		@table_display = false
		@noexcelmsg = "本日は日曜日です．" if wday==0
	end
	
	#グラフ用データ
	wdaylist = ["Mon","Tue","Wed","Thu","Fri","Sat"]

	f_ship_list = [] #出荷
	f_make_list = [] #製造
	f_makepred_list = [] #製造（予測）
	f_store_list = [] #保存
	f_pred_list = [] #出荷（予測）
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
			f_store_list.push([wdaylist[i-1],amount.f_store]) if amount.f_store!=0
			z_store_list.push([wdaylist[i-1],amount.z_store]) if amount.z_store!=0
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
			f_store_list.push([wdaylist[i-1],amount.f_store]) if amount.f_store!=0
			z_store_list.push([wdaylist[i-1],amount.z_store]) if amount.z_store!=0
		end
	end
	
	
	#翌週分
	f_makepred_nw_list = [] #製造（予測）
	f_store_nw_list = [] #保存
	f_pred_nw_list = [] #出荷（予測）
	z_makepred_nw_list = []
	z_store_nw_list = []
	z_pred_nw_list = []
	other_pred_nw_list = []
	
	for i in 1..6 do
		if Amount.exists?(:date => date.ago(wday.day).since((7+i).day))
			amount = Amount.find_by(date: date.ago(wday.day).since((7+i).day))
			f_pred_nw_list.push([wdaylist[i-1],amount.f_pred]) if amount.f_pred!=0
			z_pred_nw_list.push([wdaylist[i-1],amount.z_pred]) if amount.z_pred!=0
			other_pred_nw_list.push([wdaylist[i-1],amount.other_pred]) if amount.other_pred!=0
			f_makepred_nw_list.push([wdaylist[i-1],amount.f_pred-amount.f_stored]) if amount.f_pred-amount.f_stored>0
			z_makepred_nw_list.push([wdaylist[i-1],amount.z_pred-amount.z_stored]) if amount.z_pred-amount.z_stored>0
			f_store_nw_list.push([wdaylist[i-1],amount.f_store]) if amount.f_store!=0
			z_store_nw_list.push([wdaylist[i-1],amount.z_store]) if amount.z_store!=0
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
	
	@chart_data3 = [
	{name:"None",data:[["Mon",0],["Tue",0],["Wed",0],["Thu",0],["Fri",0],["Sat",0]]},
	{name:"F予測",data:f_makepred_nw_list},
	{name:"全卵予測",data:z_makepred_nw_list},
	{name:"その他予測",data:other_pred_nw_list},
	{name:"F作り置き",data:f_store_nw_list},
	{name:"全卵作り置き",data:z_store_nw_list}
	]
	
	@chart_data4 = [
	{name:"None",data:[["Mon",0],["Tue",0],["Wed",0],["Thu",0],["Fri",0],["Sat",0]]},
	{name:"F予測",data:f_pred_nw_list},
	{name:"全卵予測",data:z_pred_nw_list},
	{name:"その他予測",data:other_pred_nw_list}
	]
  end

  def conf
	@products = Product.where(company: 1)
	@materials = Material.where(company: 1)
  end

  def stock
  end
  
end
