cmake_minimum_required(VERSION 3.28.0)
project(build_var_spoof)

find_package(cxx REQUIRED CONFIG)
link_libraries(cxx::cxx)

add_library(my_logging STATIC logging/logging.cpp)

target_include_directories(my_logging PUBLIC logging/include)

target_link_libraries(my_logging log)

add_library(zygisk SHARED zygisk/main.cpp)
target_link_libraries(zygisk PRIVATE log my_logging)
