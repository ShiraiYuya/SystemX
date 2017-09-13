# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

@p1 = Product.new
@p1.company = 1
@p1.name = 'product1'
@p1.storage = 1
@p1.timelimit = 2
@p1.save

@m1 = Material.new
@m1.company = 1
@m1.name = 'milk'
@m1.save

@pm1 = ProductMaterial.new
@pm1.product_id = 1
@pm1.material_id = 1
@pm1.quantity = 80
@pm1.save