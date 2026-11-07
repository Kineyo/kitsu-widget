cmake_minimum_required(VERSION 3.16)
project(kitsu VERSION 2.4.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/src/include)

if(UNIX AND NOT APPLE)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(GLIB REQUIRED glib-2.0 gio-2.0)
    pkg_check_modules(X11 REQUIRED x11 xfixes xi)

    include_directories(${GLIB_INCLUDE_DIRS} ${X11_INCLUDE_DIRS})
    link_directories(${GLIB_LIBRARY_DIRS} ${X11_LIBRARY_DIRS})

    # 1. Native Lua C++ Module (qwen_native.so / kitsu_native.so)
    add_library(qwen_native SHARED src/qwen_native.cpp)
    set_target_properties(qwen_native PROPERTIES
        PREFIX ""
        OUTPUT_NAME "qwen_native"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/lib"
    )
    target_compile_options(qwen_native PRIVATE -O2 -Wall -Wextra -Wno-unused-parameter)
    target_link_libraries(qwen_native PRIVATE
        ${GLIB_LIBRARIES}
        ${X11_LIBRARIES}
        pthread
        dl
    )
    add_custom_command(TARGET qwen_native POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:qwen_native> "${CMAKE_CURRENT_SOURCE_DIR}/lib/kitsu_native.so"
    )

    # 2. POSIX mmap page-cache eviction guard for llama-server (< 500 MB RAM budget)
    add_library(qwen_mmap_guard SHARED src/qwen_mmap_guard.c)
    set_target_properties(qwen_mmap_guard PROPERTIES
        OUTPUT_NAME "qwen_mmap_guard"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/lib"
    )
    target_compile_options(qwen_mmap_guard PRIVATE -O2 -Wall)
    target_link_libraries(qwen_mmap_guard PRIVATE pthread)

    # 3. Embedded binary launcher (kitsu-bin & qwen-widget-bin)
    add_executable(kitsu-bin src/qwen_runner.cpp)
    set_target_properties(kitsu-bin PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin"
    )
    target_compile_options(kitsu-bin PRIVATE -O2 -Wall)
    add_custom_command(TARGET kitsu-bin POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:kitsu-bin> "${CMAKE_CURRENT_SOURCE_DIR}/bin/qwen-widget-bin"
    )

elseif(WIN32)
    add_compile_definitions(WIN32_LEAN_AND_MEAN NOMINMAX)

    include(FetchContent)
    FetchContent_Declare(
        lua53_src
        URL https://www.lua.org/ftp/lua-5.3.6.tar.gz
        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    )
    FetchContent_MakeAvailable(lua53_src)

    file(GLOB LUA_CORE_SOURCES
        "${lua53_src_SOURCE_DIR}/src/*.c"
    )
    list(FILTER LUA_CORE_SOURCES EXCLUDE REGEX ".*(lua|luac)\\.c$")

    # Build Lua 5.3 runtime DLL and static import lib
    add_library(lua53 SHARED ${LUA_CORE_SOURCES})
    target_compile_definitions(lua53 PRIVATE LUA_BUILD_AS_DLL LUA_LIB LUA_CORE)
    target_include_directories(lua53 PUBLIC "${lua53_src_SOURCE_DIR}/src")
    set_target_properties(lua53 PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/lib"
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/lib"
    )

    # Build standalone Lua 5.3 interpreter executable
    add_executable(lua53-bin "${lua53_src_SOURCE_DIR}/src/lua.c")
    set_target_properties(lua53-bin PROPERTIES
        OUTPUT_NAME "lua53"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin"
    )
    target_link_libraries(lua53-bin PRIVATE lua53)

    # 1. Native Lua C++ Module (qwen_native.dll / kitsu_native.dll)
    add_library(qwen_native SHARED src/qwen_native.cpp)
    set_target_properties(qwen_native PROPERTIES
        PREFIX ""
        OUTPUT_NAME "qwen_native"
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/lib"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/lib"
    )
    target_compile_definitions(qwen_native PRIVATE LUA_BUILD_AS_DLL)
    if(MSVC)
        target_compile_options(qwen_native PRIVATE /O2 /W3)
    else()
        target_compile_options(qwen_native PRIVATE -O2 -Wall)
    endif()
    target_link_libraries(qwen_native PRIVATE lua53 user32 ole32 shell32 psapi)
    add_custom_command(TARGET qwen_native POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:qwen_native> "${CMAKE_CURRENT_SOURCE_DIR}/lib/kitsu_native.dll"
    )

    # 2. Embedded binary launcher (kitsu-bin.exe & qwen-widget-bin.exe)
    add_executable(kitsu-bin src/qwen_runner.cpp)
    set_target_properties(kitsu-bin PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin"
    )
    if(MSVC)
        target_compile_options(kitsu-bin PRIVATE /O2 /W3)
    else()
        target_compile_options(kitsu-bin PRIVATE -O2 -Wall)
    endif()
    add_custom_command(TARGET kitsu-bin POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:kitsu-bin> "${CMAKE_CURRENT_SOURCE_DIR}/bin/qwen-widget-bin.exe"
    )

elseif(APPLE)
    add_library(qwen_native SHARED src/qwen_native.cpp)
    set_target_properties(qwen_native PROPERTIES
        PREFIX ""
        SUFFIX ".so"
        OUTPUT_NAME "qwen_native"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/lib"
    )
    target_compile_options(qwen_native PRIVATE -O2 -Wall)
    target_link_libraries(qwen_native PRIVATE "-undefined dynamic_lookup" "-framework ApplicationServices" "-framework CoreFoundation")

    add_executable(kitsu-bin src/qwen_runner.cpp)
    set_target_properties(kitsu-bin PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/bin"
    )
    target_compile_options(kitsu-bin PRIVATE -O2 -Wall)
    add_custom_command(TARGET kitsu-bin POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_FILE:kitsu-bin> "${CMAKE_CURRENT_SOURCE_DIR}/bin/qwen-widget-bin"
    )
endif()
