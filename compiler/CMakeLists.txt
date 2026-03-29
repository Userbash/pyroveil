add_library(glsl-compiler STATIC compiler.cpp compiler.hpp)
target_include_directories(glsl-compiler PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_options(glsl-compiler PRIVATE ${PYROVEIL_CXX_FLAGS})
target_link_libraries(glsl-compiler PUBLIC SPIRV-Headers PRIVATE shaderc)
