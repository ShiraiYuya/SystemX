# -*- coding: utf-8 -*-
"""
2015~2017年度注文履歴.xlsxと商品リスト.csvから
淡路麺業の需要に関するデータベースを作成する
・order_raw：一注文ごとの詳細
・order_daysum：一日ごとの発送量累計(朝4時まで(morning)と合計)
DATABASE名：pasta
"""
import csv
import xlrd
import unicodedata
import datetime as dt
from datetime import date
import mysql.connector

dbcon = mysql.connector.connect(
database="systemx", 
user="user", 
password="pass", 
host="localhost",
buffered=True)
dbcur = dbcon.cursor()

#1 商品リストのテーブルを作る
"""
商品No	製品名	形状	サイズ(g)	入数	単価	1c/s単価	2c/s単価	3c/s単価	4c/s単価	タイプ
10108	全卵	タリアテッレ	80	64	64	0	0	0	0	プレーン
"""
dbcur.execute("CREATE TABLE products_list (id INT PRIMARY KEY AUTO_INCREMENT," 
              "product_id INT, name CHAR(18), shape_name CHAR(18), weight INT, case_num INT," 
              "type CHAR(8))")

with open("forDB/productlist.csv") as csvfile:
    reader = csv.reader(csvfile)
    next(reader)
    input_row=[]
    for row in reader:
        name=unicodedata.normalize('NFKC', row[1])
        shape_name=unicodedata.normalize('NFKC', row[2])
        input_row.append((0,int(row[0]),name,shape_name,int(row[3]),int(row[4]),row[10]))
    dbcur.executemany("INSERT INTO products_list VALUES(%s,%s,%s,%s,%s,%s,%s)",input_row)
    dbcon.commit()

#2 商品リストのテーブルから辞書を作っておく
products_list={}
dbcur.execute("SELECT product_id, name, shape_name, case_num FROM products_list")
for row in dbcur.fetchall():
    products_list[row[0]]=row[1:]

#3 注文履歴をデータベースに落とし込む
dbcur.execute("CREATE TABLE order_raw (id INT PRIMARY KEY AUTO_INCREMENT, order_id INT," 
              "client_id INT, order_seq FLOAT(12,6), order_day DATE, order_time TIME," 
              "to_deli_day DATE, from_deli_day DATE, from_deli_time CHAR(15)," 
              "product_id INT, name_id INT, name CHAR(18), shape_id INt," 
              "shape_name CHAR(18), type CHAR(8), weight INT, num INT, total_weight FLOAT(8,3))")
fname="年度注文履歴.xlsx"
data_num=0
err=[]
for year in range(2015,2018):
    book = xlrd.open_workbook("forDB/"+str(year)+fname)
    sheet_names = book.sheet_names()
    input_row=[]
    for i in range(book.nsheets):
        print(sheet_names[i])
        sheet = book.sheet_by_index(i)
        for j in range(1,sheet.nrows):
            row=sheet.row_values(j)
            if row[0]=="":
                break
            order_id=int(row[0])
            client_id=int(row[4])
            order_seq=float(row[1])
            order_dt=dt.datetime(1899, 12, 30)+dt.timedelta(days=float(row[1]))
            order_day=dt.date(order_dt.year,order_dt.month,order_dt.day)
            order_time=dt.time(order_dt.hour,order_dt.minute)
            to_deli_dt=dt.datetime(1899, 12, 30)+dt.timedelta(days=float(row[2]))
            to_deli_day=dt.date(to_deli_dt.year,to_deli_dt.month,to_deli_dt.day)
            day_dt=row[3].split("-")
            from_deli_day=dt.date(int(day_dt[0]),int(day_dt[1]),int(day_dt[2]))
            from_deli_time=row[6]
            product_id=int(row[18])
            name_id=int(row[19])
            if product_id not in products_list:
                err.append([order_id,order_day,product_id])
                continue
            name=products_list[product_id][0]
            shape_id=int(row[20])
            shape_name=products_list[product_id][1]
            product_type=row[22]
            weight=int(row[21])
            if int(row[24])>0:
                num=int(row[24])
            else:
                num=products_list[product_id][2]*int(row[23])
            total_weight=weight*num/1000.0
            input_row.append((0,order_id,client_id,order_seq,order_day,order_time,to_deli_day,from_deli_day,from_deli_time,product_id,name_id,name,shape_id,shape_name,product_type,weight,num,total_weight))
#            print((order_id,client_id,order_seq,order_day,order_time,to_deli_day,from_deli_day,from_deli_time,product_id,name_id,name,shape_id,shape_name,product_type,weight,num,total_weight))
            data_num+=1
            if data_num%1000==0:
                dbcur.executemany("INSERT INTO order_raw VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",input_row)
                dbcon.commit()
                print("1000件挿入")
                input_row=[]
if data_num%1000>0:
    dbcur.executemany("INSERT INTO order_raw VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",input_row)
    dbcon.commit()
    print(str(data_num%1000)+"件挿入")

dbcur.execute("ALTER TABLE order_raw ADD INDEX order_date_index(order_day)")
dbcur.execute("ALTER TABLE order_raw ADD INDEX order_time_index(order_day, order_time)")
dbcur.execute("ALTER TABLE order_raw ADD INDEX deli_date_index(from_deli_day)")

dbcon.commit()

#4 一日ごとのsumテーブルを作る
dbcur.execute("CREATE TABLE order_daysum (id INT PRIMARY KEY AUTO_INCREMENT, from_deli_day DATE," 
              "f_ship_morning FLOAT(8,3), f_ship FLOAT(8,3), z_ship_morning FLOAT(8,3)," 
              "z_ship FLOAT(8,3), other_ship_morning FLOAT(8,3), other_ship FLOAT(8,3))")

target_day = date(2015,4,6)
while target_day<=date(2017,9,18):
    dbcur.execute("SELECT SUM(total_weight) FROM order_raw WHERE name='F' AND from_deli_day=%s AND " 
                  "(order_day<%s OR (order_day=%s AND order_time<=%s))", 
                  (target_day, target_day, target_day, dt.time(4,0,0)))
    f_ship_morning = dbcur.fetchone()[0]
    if f_ship_morning is None:
        f_ship_morning = 0
    dbcur.execute("SELECT SUM(total_weight) FROM order_raw WHERE name='F' AND from_deli_day=%s",(target_day,))
    f_ship = dbcur.fetchone()[0]
    if f_ship is None:
        f_ship = 0
    dbcur.execute("SELECT SUM(total_weight) FROM order_raw WHERE name='全卵' AND from_deli_day=%s AND " 
                  "(order_day<%s OR (order_day=%s AND order_time<=%s))", 
                  (target_day, target_day, target_day, dt.time(4,0,0)))
    z_ship_morning = dbcur.fetchone()[0]
    if z_ship_morning is None:
        z_ship_morning = 0
    dbcur.execute("SELECT SUM(total_weight) FROM order_raw WHERE name='全卵' AND from_deli_day=%s",(target_day,))
    z_ship = dbcur.fetchone()[0]
    if z_ship is None:
        z_ship = 0
    dbcur.execute("SELECT SUM(total_weight) FROM order_raw WHERE from_deli_day=%s AND " 
                  "(order_day<%s OR (order_day=%s AND order_time<=%s))", 
                  (target_day, target_day, target_day, dt.time(4,0,0)))
    all_ship_morning = dbcur.fetchone()[0]
    if all_ship_morning is None:
        all_ship_morning = 0
    other_ship_morning = all_ship_morning - f_ship_morning - z_ship_morning
    dbcur.execute("SELECT SUM(total_weight) FROM order_raw WHERE from_deli_day=%s",(target_day,))
    all_ship = dbcur.fetchone()[0]
    if all_ship is None:
        all_ship = 0
    other_ship = all_ship - f_ship - z_ship
    input_row=(0,target_day,f_ship_morning,f_ship,z_ship_morning,z_ship,other_ship_morning,other_ship)
    dbcur.execute("INSERT INTO order_daysum VALUES(%s,%s,%s,%s,%s,%s,%s,%s)",input_row)
    target_day += dt.timedelta(days=1)
    if target_day.weekday() == 6:
        target_day += dt.timedelta(days=1)
dbcur.execute("ALTER TABLE order_daysum ADD INDEX deli_date_index(from_deli_day)")

dbcon.commit()
dbcur.close()
dbcon.close()