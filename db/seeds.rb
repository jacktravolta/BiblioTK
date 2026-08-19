# db/seeds.rb al final
start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

# ... todo tu código de crear books/users/reviews ...

elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

FileUtils.mkdir_p("tmp")
File.write("tmp/data_generation_timing.txt", <<~TXT)
  Books: #{Book.count}
  Users: #{User.count}
  Reviews: #{Review.count}
  Tiempo: #{elapsed.round(2)}s
  Fecha: #{Time.now}
TXT

puts "Timing guardado en tmp/data_generation_timing.txt"