# Build the PyroVeil Vulkan layer shared library
# Includes: main layer implementation, auto-detection module, hash utilities
add_library(VkLayer_pyroveil SHARED 
    pyroveil.cpp 
    pyroveil_autodetect.cpp
    fossilize_hasher.hpp
)

# Link required dependencies:
# - glsl-compiler: GLSL to SPIRV compilation
# - spirv-cross-glsl: SPIRV cross-compilation and reflection
# - Vulkan-Headers: Vulkan API definitions
# - layer-util: Dispatch helpers and utilities
# - rapidjson-headers: JSON parsing for configuration files
target_link_libraries(VkLayer_pyroveil PRIVATE 
    glsl-compiler 
    spirv-cross-glsl 
    Vulkan-Headers 
    layer-util 
    rapidjson-headers
)

target_include_directories(VkLayer_pyroveil PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_compile_options(VkLayer_pyroveil PRIVATE ${PYROVEIL_CXX_FLAGS})
set_target_properties(VkLayer_pyroveil PROPERTIES LINK_FLAGS "${PYROVEIL_LINK_FLAGS}")

install(TARGETS VkLayer_pyroveil
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR})

file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/layer)

if (CMAKE_SIZEOF_VOID_P EQUAL 8)
	set(PYROVEIL_ABI_TAG "_64")
else()
	set(PYROVEIL_ABI_TAG "_32")
endif()

# First is a JSON file which can be used directly from the build folder.
if (WIN32)
    set(PYROVEIL_LAYER_PATH ".\\\\VkLayer_pyroveil${PYROVEIL_ABI_TAG}.dll")
else()
    set(PYROVEIL_LAYER_PATH "./libVkLayer_pyroveil${PYROVEIL_ABI_TAG}.so")
endif()

configure_file(${CMAKE_CURRENT_SOURCE_DIR}/VkLayer_pyroveil.json.in ${CMAKE_BINARY_DIR}/layer/VkLayer_pyroveil${PYROVEIL_ABI_TAG}.json @ONLY)

if (WIN32)
    set_target_properties(VkLayer_pyroveil PROPERTIES PREFIX "" LIBRARY_OUTPUT_NAME VkLayer_pyroveil${PYROVEIL_ABI_TAG})
    if (CMAKE_COMPILER_IS_GNUCXX)
        if (${CMAKE_BUILD_TYPE} MATCHES "Release")
            set_target_properties(VkLayer_pyroveil PROPERTIES LINK_FLAGS "${PYROVEIL_LINK_FLAGS} -Wl,--no-undefined -static -s")
        else()
            set_target_properties(VkLayer_pyroveil PROPERTIES LINK_FLAGS "${PYROVEIL_LINK_FLAGS} -Wl,--no-undefined -static")
        endif()
    endif()
    # Normally, we would have to install the layer into the registry, but that is way too annoying for something like this.
    # Just place the layer along the dll on Windows if we're actually bothering to install.
    configure_file(${CMAKE_CURRENT_SOURCE_DIR}/VkLayer_pyroveil.json.in ${CMAKE_BINARY_DIR}/VkLayer_pyroveil${PYROVEIL_ABI_TAG}.json @ONLY)
    install(FILES ${CMAKE_BINARY_DIR}/VkLayer_pyroveil${PYROVEIL_ABI_TAG}.json DESTINATION ${CMAKE_INSTALL_BINDIR})
else()
    set_target_properties(VkLayer_pyroveil PROPERTIES LIBRARY_OUTPUT_NAME VkLayer_pyroveil${PYROVEIL_ABI_TAG})
    # In some environments (like nix sandbox) the CMAKE_INSTALL_*DIR may be set
    # to absolute paths, in another - to relative to CMAKE_INSTALL_PREFIX.
    if(IS_ABSOLUTE "${CMAKE_INSTALL_LIBDIR}")
        set(PYROVEIL_LAYER_PATH "${CMAKE_INSTALL_LIBDIR}/libVkLayer_pyroveil${PYROVEIL_ABI_TAG}.so")
    else()
        set(PYROVEIL_LAYER_PATH "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/libVkLayer_pyroveil${PYROVEIL_ABI_TAG}.so")
    endif()
    configure_file(${CMAKE_CURRENT_SOURCE_DIR}/VkLayer_pyroveil.json.in ${CMAKE_BINARY_DIR}/VkLayer_pyroveil${PYROVEIL_ABI_TAG}.json @ONLY)
    install(FILES ${CMAKE_BINARY_DIR}/VkLayer_pyroveil${PYROVEIL_ABI_TAG}.json DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/vulkan/implicit_layer.d)
    if (${CMAKE_BUILD_TYPE} MATCHES "Release")
        set_target_properties(VkLayer_pyroveil PROPERTIES LINK_FLAGS "${PYROVEIL_LINK_FLAGS} -Wl,--no-undefined -s")
    else()
        set_target_properties(VkLayer_pyroveil PROPERTIES LINK_FLAGS "${PYROVEIL_LINK_FLAGS} -Wl,--no-undefined")
    endif()
endif()

set_target_properties(VkLayer_pyroveil PROPERTIES RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_BINARY_DIR}/layer")
set_target_properties(VkLayer_pyroveil PROPERTIES RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_BINARY_DIR}/layer")
set_target_properties(VkLayer_pyroveil PROPERTIES RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL "${CMAKE_BINARY_DIR}/layer")
set_target_properties(VkLayer_pyroveil PROPERTIES RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO "${CMAKE_BINARY_DIR}/layer")
