//
// Copyright (C) 2024 The Goldfish Scheme Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations
// under the License.
//

#include <chrono>
#include <iostream>
#include <s7.h>
#include <string>
#include <tbox/tbox.h>

inline void glue_goldfish (s7_scheme* sc);
inline void glue_scheme_time (s7_scheme* sc);
inline void glue_scheme_process_context (s7_scheme* sc);

const int patch_version= 0;                // Goldfish Patch Version
const int minor_version= S7_MAJOR_VERSION; // S7 Major Version
const int major_version= 17;               // C++ Standard version

const std::string goldfish_version=
    std::to_string (major_version)
        .append (".")
        .append (std::to_string (minor_version))
        .append (".")
        .append (std::to_string (patch_version));

// Glues for Goldfish
static s7_pointer
f_version (s7_scheme* sc, s7_pointer args) {
  return s7_make_string (sc, goldfish_version.c_str ());
}

inline void
glue_goldfish (s7_scheme* sc) {
  s7_pointer cur_env= s7_curlet (sc);

  const char* s_version= "version";
  const char* d_version= "(version) => string, return the "
                         "goldfish version";
  s7_define (sc, cur_env, s7_make_symbol (sc, s_version),
             s7_make_typed_function (sc, s_version, f_version, 0, 0, false,
                                     d_version, NULL));
}

// Glues for (scheme time)
static s7_pointer
f_current_second (s7_scheme* sc, s7_pointer args) {
  auto now= std::chrono::system_clock::now ();
  // TODO: use std::chrono::tai_clock::now() when using C++ 20
  auto      now_duration= now.time_since_epoch ();
  double    ts          = std::chrono::duration<double> (now_duration).count ();
  s7_double res         = ts;
  return s7_make_real (sc, res);
}

inline void
glue_scheme_time (s7_scheme* sc) {
  s7_pointer cur_env= s7_curlet (sc);

  const char* s_current_second= "g_current-second";
  const char* d_current_second= "(g_current-second) => double, return the "
                                "current unix timestamp in double";
  s7_define (sc, cur_env, s7_make_symbol (sc, s_current_second),
             s7_make_typed_function (sc, s_current_second, f_current_second, 0,
                                     0, false, d_current_second, NULL));
}

// Glues for (scheme process-context)
static s7_pointer
f_get_environment_variable (s7_scheme* sc, s7_pointer args) {
#ifdef _MSC_VER
  std::string path_sep= ";";
#else
  std::string path_sep= ":";
#endif
  std::string          ret;
  tb_size_t            size       = 0;
  const char*          key        = s7_string (s7_car (args));
  tb_environment_ref_t environment= tb_environment_init ();
  if (environment) {
    size= tb_environment_load (environment, key);
    if (size >= 1) {
      tb_for_all_if (tb_char_t const*, value, environment, value) {
        ret.append (value).append (path_sep);
      }
    }
  }
  tb_environment_exit (environment);
  if (size == 0) { // env key not found
    return s7_make_boolean (sc, false);
  }
  else {
    return s7_make_string (sc, ret.substr (0, ret.size () - 1).c_str ());
  }
}

inline void
glue_scheme_process_context (s7_scheme* sc) {
  s7_pointer  cur_env                   = s7_curlet (sc);
  const char* s_get_environment_variable= "g_get-environment-variable";
  const char* d_get_environment_variable=
      "(g_get-environemt-variable string) => string";
  s7_define (sc, cur_env, s7_make_symbol (sc, s_get_environment_variable),
             s7_make_typed_function (sc, s_get_environment_variable,
                                     f_get_environment_variable, 1, 0, false,
                                     d_get_environment_variable, NULL));
}
