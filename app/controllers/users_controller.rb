require 'roo-xls'

class UsersController < ApplicationController
  def index
  
	#1→日曜なので非表示，2→is_defが必要(excelフォームのみ出現)，
	#3→is_finが必要(excelフォームと表修正フォームが出現)，4→正常(表を表示)	※グラフは1の場合以外表示
	@view_mode = 0
	
	#excelを受け取って出荷量（f,z,other別）をDBとpythonに渡す
	if params[:file] != nil
		#excelの取得
		xls = Roo::Excel.new(params[:file].path)
		xls.default_sheet = '出荷台帳（入力順）'		
		shipdate = Date.strptime(xls.cell(2,3).encode("UTF-8"),'%m/%d ')
		setting_fin = (params[:setting_fin]=='false' ? false : true)
		supposed_date = Date.strptime(params[:supposed_date],'%Y-%m-%d')
		supdate_str = supposed_date.strftime("%m月%d日")
		if shipdate == supposed_date
			
			regist_xls(xls, shipdate, setting_fin)
			
			if setting_fin
				@tabledate = Amount.find_or_create_by(date: shipdate)
				@view_mode = 3
				@noexcelmsg = supdate_str+"の製造量を更新しました．値に間違いがなければ確認ボタンを押してください．"
			else
				#ここでpythonを実行
				regist_py(shipdate)
			end
		elsif setting_fin
			@noexcelmsg = "正しいエクセルファイルが登録されていません．<br>".html_safe+supdate_str+"のファイルを登録してください．"
			@tabledate = Amount.find_or_create_by(date: supposed_date)
			@view_mode = 3
			
		else
			@noexcelmsg = "正しいエクセルファイルが登録されていません．<br>".html_safe+supdate_str+"のファイルを登録してください．"
			@tabledate = Amount.find_or_create_by(date: supposed_date)
			@view_mode = 2
		end
	end
	#ここまでexcel受け取り時の処理
	
	#作り置き製造量の実績値を受け取ってDBに渡す
	if params[:commit] == "確定"
		supposed_date = Date.strptime(params[:supposed_date],'%Y-%m-%d')
		amount = Amount.find_by(date: supposed_date)
		amount.update(f_store: params[:f_result],z_store: params[:z_result], is_fin: true)
		if supposed_date.wday != 6
			amount = Amount.find_by(date: supposed_date.tomorrow)
			amount.update(f_stored: params[:f_result],z_stored: params[:z_result])
		end
	end
	
	
	#本日のデータ取得
	@time = Time.zone.now
	date = Time.zone.today
	date = date.ago(0.day)
	wday = date.wday
	
	if wday == 0
		@noexcelmsg = "本日は日曜日です．"
		@view_mode = 1
	end
	
	
	#情報更新不足の確認
	if @view_mode == 0
		iday = date.ago((wday+1).day)
		amount = Amount.find_or_create_by(date: iday)
		if amount.is_def and !amount.is_fin
			@supposed_date = iday
			supdate_str = iday.strftime("%m月%d日")
			@noexcelmsg = supdate_str+"分の情報を更新してください．"
			@setting_fin = true
			@tabledate = amount
			@view_mode = 3
		end
	end
	
	jwdaylist = ["月曜","火曜","水曜","木曜","金曜","土曜"]
	for i in 1..(wday-1) do
		iday = date.ago(wday.day).since(i.day)
		if @view_mode == 0
			amount = Amount.find_or_create_by(date: iday)
			@supposed_date = iday
			supdate_str = iday.strftime("%m月%d日")
			if !amount.is_def
				@noexcelmsg = supdate_str+"分のエクセルファイルを入力してください．"
				@setting_fin = false
				@tabledate = amount
				@view_mode = 2
			elsif !amount.is_fin
				@noexcelmsg = supdate_str+"分の情報を更新してください．"
				@setting_fin = true
				@tabledate = amount
				@view_mode = 3
			end
		end	
	end
	
	if @view_mode == 0
		amount = Amount.find_or_create_by(date: date)
		if amount.is_def
			@today = amount
			@view_mode = 4
		else
			@supposed_date = date
			@noexcelmsg = "本日分のエクセルファイルを入力してください．"
			@setting_fin = false
			@tabledate = amount
			@view_mode = 2
		end		
	end
	
	view_graph()
  end

  def conf
	@products = Product.where(company: 1)
	@materials = Material.where(company: 1)
  end

  def stock
  end
  
  
  
  def regist_xls(xls, shipdate, setting_fin)
	swday = shipdate.wday
		
	#出荷量の算出
	f,zenran,other = 0,0,0
	for i in 4..xls.last_row do
		if xls.cell(i, 4) != nil
			product = xls.cell(i, 4).encode("UTF-8")
			size = xls.cell(i, 6).tr!("０-９", "0-9").to_i
			num = xls.cell(i, 10).tr!("０-９", "0-9").to_i

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
	#初回:is_def→true,shipに加えmornも登録
	#２回目以降:shipのみ更新
	#最後（翌日）:is_fin→true,ship更新
	amount = Amount.find_or_create_by(date: shipdate)
	if amount.is_def
		amount.update(f_ship: f, z_ship: zenran, other_ship: other)
	else
		amount.update(f_ship: f, f_morn: f, z_ship: zenran,z_morn: zenran, other_ship: other, other_morn: other, is_def: true)
	end	
  end
  
  
  def regist_py(shipdate)
	swday = shipdate.wday
  
	#受け取りは各日の予測出荷量（f,z,other別）：月から日まで
	f_py = [0,800,700,700,800,1500,0]
	z_py = [0,750,700,650,750,1400,0]
	other_py = [0,1200,1200,1300,1400,1800,0]
	f_nw_py = [850,800,750,750,850,1400,0]
	z_nw_py = [700,650,700,750,800,1300,0]
	other_nw_py = [1100,1200,1150,1300,1300,1900,0]
	#ここでshipが確定しているものがあれば置き換える
	
	
	#shipdate~土までに作る総量sum（f,z,other別），平均averを算出
	amount = Amount.find_by(date: shipdate)
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
	
	#shipdateの次の日以降のship(予測),stored,store登録
	for i in (swday+1)..6 do		
		aver = sum / (7 - i)
		amount = Amount.find_or_create_by(date: shipdate.ago(swday.day).since(i.day))
		amount.update(f_stored: f_store, z_stored: z_store, f_ship: f_py[i-1] , z_ship: z_py[i-1], other_ship: other_py[i-1])
		
		store = [aver - (f_py[i-1] + z_py[i-1] + other_py[i-1] - store), 0].max
		f_store = (-z_sum * (f_py[i-1] - f_store) + f_sum * (z_py[i-1] - z_store + store) ) / (z_sum + f_sum)
		f_store = [[f_store,store,f_py[i]].min, 0].max
		z_store = [store - f_store, z_py[i]].min
		
		amount.update(f_store: f_store, z_store: z_store)
		
		sum -= (amount.f_ship - amount.f_stored + amount.f_store) + (amount.z_ship - amount.z_stored + amount.z_store) + amount.other_ship
		f_sum -= amount.f_ship - amount.f_stored + amount.f_store
		z_sum -= amount.z_ship - amount.z_stored + amount.z_store
	end
	
	#翌週月~土までに作る総量sum（f,z,other別），平均averを算出
	f_sum = f_nw_py.sum
	z_sum = z_nw_py.sum
	other_sum = other_nw_py.sum
	sum = f_sum + z_sum + other_sum
	f_store = 0
	z_store = 0
	store = 0
	
	#翌週各日のship(予測),stored,store登録
	for i in 1..6 do		
		aver = sum / (7 - i)
		amount = Amount.find_or_create_by(date: shipdate.ago(swday.day).since((7+i).day))
		amount.update(f_stored: f_store, z_stored: z_store, f_ship: f_nw_py[i-1] , z_ship: z_nw_py[i-1], other_ship: other_nw_py[i-1])
		
		store = [aver - (f_nw_py[i-1] + z_nw_py[i-1] + other_nw_py[i-1] - store), 0].max
		f_store = (-z_sum * (f_nw_py[i-1] - f_store) + f_sum * (z_nw_py[i-1] - z_store + store) ) / (z_sum + f_sum)
		f_store = [[f_store,store,f_nw_py[i]].min, 0].max
		z_store = [store - f_store, z_nw_py[i]].min
		
		amount.update(f_store: f_store, z_store: z_store)
		
		sum -= (amount.f_ship - amount.f_stored + amount.f_store) + (amount.z_ship - amount.z_stored + amount.z_store) + amount.other_ship
		f_sum -= amount.f_ship - amount.f_stored + amount.f_store
		z_sum -= amount.z_ship - amount.z_stored + amount.z_store
	end
  end
  
  
  
  
  
  
  def view_graph
	date = Time.zone.today
	wday = date.wday
	
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
	
	for i in 1..6 do
		if Amount.exists?(:date => date.ago(wday.day).since(i.day))
			amount = Amount.find_by(date: date.ago(wday.day).since(i.day))
			if amount.is_def
				f_ship_list.push([wdaylist[i-1],amount.f_ship]) if amount.f_ship!=0
				z_ship_list.push([wdaylist[i-1],amount.z_ship]) if amount.z_ship!=0
				other_ship_list.push([wdaylist[i-1],amount.other_ship]) if amount.other_ship!=0
				f_make_list.push([wdaylist[i-1],amount.f_ship-amount.f_stored]) if amount.f_ship-amount.f_stored>0
				z_make_list.push([wdaylist[i-1],amount.z_ship-amount.z_stored]) if amount.z_ship-amount.z_stored>0
			else
				f_pred_list.push([wdaylist[i-1],amount.f_ship]) if amount.f_ship!=0
				z_pred_list.push([wdaylist[i-1],amount.z_ship]) if amount.z_ship!=0
				other_pred_list.push([wdaylist[i-1],amount.other_ship]) if amount.other_ship!=0
				f_makepred_list.push([wdaylist[i-1],amount.f_ship-amount.f_stored]) if amount.f_ship-amount.f_stored>0
				z_makepred_list.push([wdaylist[i-1],amount.z_ship-amount.z_stored]) if amount.z_ship-amount.z_stored>0
			end
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
			f_pred_nw_list.push([wdaylist[i-1],amount.f_ship]) if amount.f_ship!=0
			z_pred_nw_list.push([wdaylist[i-1],amount.z_ship]) if amount.z_ship!=0
			other_pred_nw_list.push([wdaylist[i-1],amount.other_ship]) if amount.other_ship!=0
			f_makepred_nw_list.push([wdaylist[i-1],amount.f_ship-amount.f_stored]) if amount.f_ship-amount.f_stored>0
			z_makepred_nw_list.push([wdaylist[i-1],amount.z_ship-amount.z_stored]) if amount.z_ship-amount.z_stored>0
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
  
end
