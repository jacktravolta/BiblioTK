# INSTALACION DESDE CERO

bundle install
bin/rails db:drop db:create db:migrate
bin/rails db:seed
bin/rails runner /tmp/generar_datos_prueba.rb
bin/rails runner benchmark_500k.rb
bundle exec rspec -fd
bin/rails server -b 0.0.0.0 -p 3000
# http://localhost:3000/books

# Verificar indices
bin/rails runner "puts ActiveRecord::Base.connection.indexes(:books).map(&:name)"

# Test O(1) con buscador
bin/rails runner /tmp/test_busqueda_o1.rb
