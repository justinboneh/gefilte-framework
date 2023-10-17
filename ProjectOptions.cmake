include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(gefilte_framework_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(gefilte_framework_setup_options)
  option(gefilte_framework_ENABLE_HARDENING "Enable hardening" ON)
  option(gefilte_framework_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    gefilte_framework_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    gefilte_framework_ENABLE_HARDENING
    OFF)

  gefilte_framework_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR gefilte_framework_PACKAGING_MAINTAINER_MODE)
    option(gefilte_framework_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(gefilte_framework_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(gefilte_framework_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(gefilte_framework_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(gefilte_framework_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(gefilte_framework_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(gefilte_framework_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(gefilte_framework_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(gefilte_framework_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(gefilte_framework_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(gefilte_framework_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(gefilte_framework_ENABLE_PCH "Enable precompiled headers" OFF)
    option(gefilte_framework_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(gefilte_framework_ENABLE_IPO "Enable IPO/LTO" ON)
    option(gefilte_framework_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(gefilte_framework_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(gefilte_framework_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(gefilte_framework_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(gefilte_framework_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(gefilte_framework_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(gefilte_framework_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(gefilte_framework_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(gefilte_framework_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(gefilte_framework_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(gefilte_framework_ENABLE_PCH "Enable precompiled headers" OFF)
    option(gefilte_framework_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      gefilte_framework_ENABLE_IPO
      gefilte_framework_WARNINGS_AS_ERRORS
      gefilte_framework_ENABLE_USER_LINKER
      gefilte_framework_ENABLE_SANITIZER_ADDRESS
      gefilte_framework_ENABLE_SANITIZER_LEAK
      gefilte_framework_ENABLE_SANITIZER_UNDEFINED
      gefilte_framework_ENABLE_SANITIZER_THREAD
      gefilte_framework_ENABLE_SANITIZER_MEMORY
      gefilte_framework_ENABLE_UNITY_BUILD
      gefilte_framework_ENABLE_CLANG_TIDY
      gefilte_framework_ENABLE_CPPCHECK
      gefilte_framework_ENABLE_COVERAGE
      gefilte_framework_ENABLE_PCH
      gefilte_framework_ENABLE_CACHE)
  endif()

  gefilte_framework_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (gefilte_framework_ENABLE_SANITIZER_ADDRESS OR gefilte_framework_ENABLE_SANITIZER_THREAD OR gefilte_framework_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(gefilte_framework_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(gefilte_framework_global_options)
  if(gefilte_framework_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    gefilte_framework_enable_ipo()
  endif()

  gefilte_framework_supports_sanitizers()

  if(gefilte_framework_ENABLE_HARDENING AND gefilte_framework_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR gefilte_framework_ENABLE_SANITIZER_UNDEFINED
       OR gefilte_framework_ENABLE_SANITIZER_ADDRESS
       OR gefilte_framework_ENABLE_SANITIZER_THREAD
       OR gefilte_framework_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${gefilte_framework_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${gefilte_framework_ENABLE_SANITIZER_UNDEFINED}")
    gefilte_framework_enable_hardening(gefilte_framework_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(gefilte_framework_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(gefilte_framework_warnings INTERFACE)
  add_library(gefilte_framework_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  gefilte_framework_set_project_warnings(
    gefilte_framework_warnings
    ${gefilte_framework_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(gefilte_framework_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(gefilte_framework_options)
  endif()

  include(cmake/Sanitizers.cmake)
  gefilte_framework_enable_sanitizers(
    gefilte_framework_options
    ${gefilte_framework_ENABLE_SANITIZER_ADDRESS}
    ${gefilte_framework_ENABLE_SANITIZER_LEAK}
    ${gefilte_framework_ENABLE_SANITIZER_UNDEFINED}
    ${gefilte_framework_ENABLE_SANITIZER_THREAD}
    ${gefilte_framework_ENABLE_SANITIZER_MEMORY})

  set_target_properties(gefilte_framework_options PROPERTIES UNITY_BUILD ${gefilte_framework_ENABLE_UNITY_BUILD})

  if(gefilte_framework_ENABLE_PCH)
    target_precompile_headers(
      gefilte_framework_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(gefilte_framework_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    gefilte_framework_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(gefilte_framework_ENABLE_CLANG_TIDY)
    gefilte_framework_enable_clang_tidy(gefilte_framework_options ${gefilte_framework_WARNINGS_AS_ERRORS})
  endif()

  if(gefilte_framework_ENABLE_CPPCHECK)
    gefilte_framework_enable_cppcheck(${gefilte_framework_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(gefilte_framework_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    gefilte_framework_enable_coverage(gefilte_framework_options)
  endif()

  if(gefilte_framework_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(gefilte_framework_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(gefilte_framework_ENABLE_HARDENING AND NOT gefilte_framework_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR gefilte_framework_ENABLE_SANITIZER_UNDEFINED
       OR gefilte_framework_ENABLE_SANITIZER_ADDRESS
       OR gefilte_framework_ENABLE_SANITIZER_THREAD
       OR gefilte_framework_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    gefilte_framework_enable_hardening(gefilte_framework_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
