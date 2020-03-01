import (
	os
	filepath
)

fn testsuite_begin() {
	cleanup_leftovers()
}

fn testsuite_end() {
	cleanup_leftovers()
}

fn test_setenv() {
  os.setenv('foo', 'bar', true)
  assert os.getenv('foo') == 'bar'

  // `setenv` should not set if `overwrite` is false
  os.setenv('foo', 'bar2', false)
  assert os.getenv('foo') == 'bar'

  // `setenv` should overwrite if `overwrite` is true
  os.setenv('foo', 'bar2', true)
  assert os.getenv('foo') == 'bar2'
}

fn test_unsetenv() {
  os.setenv('foo', 'bar', true)
  os.unsetenv('foo')
  assert os.getenv('foo') == ''
}

fn test_open_file() {
  filename := './test1.txt'
  hello := 'hello world!'
  os.open_file(filename, "r+", 0o666) or {
    assert err == "No such file or directory"
  }

  mut file := os.open_file(filename, "w+", 0o666) or { panic(err) }
  file.write(hello)
  file.close()

  assert hello.len == os.file_size(filename)

  read_hello := os.read_file(filename) or {
    panic('error reading file $filename')
  }
  assert hello == read_hello

  os.remove(filename)
}

fn test_create_file() {
	filename := './test1.txt'
	hello := 'hello world!'
	mut f := os.create(filename) or { panic(err)}
	f.write(hello)
	f.close()

	assert hello.len == os.file_size(filename)

	os.remove(filename)
}

fn test_write_and_read_string_to_file() {
  filename := './test1.txt'
  hello := 'hello world!'
  os.write_file(filename, hello)
  assert hello.len == os.file_size(filename)

  read_hello := os.read_file(filename) or {
    panic('error reading file $filename')
  }
  assert hello == read_hello

  os.remove(filename)
}

// test_write_and_read_bytes checks for regressions made in the functions
// read_bytes, read_bytes_at and write_bytes.
/*
fn test_write_and_read_bytes() {
        file_name :=  './byte_reader_writer.tst'
        payload   :=  [`I`, `D`, `D`, `Q`, `D`]

        mut file_write := os.create(filepath.abs(file_name)) or {
                eprintln('failed to create file $file_name')
                return
        }

        // We use the standard write_bytes function to write the payload and
        // compare the length of the array with the file size (have to match).
        file_write.write_bytes(payload.data, 5)

        file_write.close()

        assert payload.len == os.file_size(file_name)

        mut file_read := os.open(filepath.abs(file_name)) or {
          eprintln('failed to open file $file_name')
          return
        }

        // We only need to test read_bytes because this function calls
        // read_bytes_at with second parameter zeroed (size, 0).
        red_bytes := file_read.read_bytes(5)

        file_read.close()

        assert red_bytes.str() == payload.str()

        // We finally delete the test file.
        os.remove(file_name)
}
*/

fn test_create_and_delete_folder() {
  folder := './test1'
  os.mkdir(folder) or { panic(err) }
	assert os.is_dir(folder)

  folder_contents := os.ls(folder) or { panic(err) }
  assert folder_contents.len == 0

  os.remove(folder)

  folder_exists := os.is_dir(folder)

  assert folder_exists == false
}

fn walk_callback(file string) {
    if file == '.' || file == '..' {
        return
    }
    assert file == 'test_walk' + filepath.separator + 'test1'
}

fn test_walk() {
    folder := 'test_walk'
    os.mkdir(folder) or { panic(err) }

    file1 := folder + filepath.separator + 'test1'

    os.write_file(file1,'test-1')

    os.walk(folder, walk_callback)

	  os.remove_all(folder)
}

fn test_copy() {
    old_file_name := 'cp_example.txt'
    new_file_name := 'cp_new_example.txt'

    os.write_file(old_file_name, 'Test data 1 2 3, V is awesome #$%^[]!~⭐')
    os.copy(old_file_name, new_file_name) or { panic('$err: errcode: $errcode') }

    old_file := os.read_file(old_file_name) or { panic(err) }
    new_file := os.read_file(new_file_name) or { panic(err) }
    assert old_file == new_file

    os.remove(old_file_name)
    os.remove(new_file_name)
}

fn test_copy_all() {
  //fileX -> dir/fileX
  // NB: clean up of the files happens inside the cleanup_leftovers function
  os.write_file('ex1.txt', 'wow!')
  os.mkdir('ex') or { panic(err) }
  os.copy_all('ex1.txt', 'ex', false) or { panic(err) }
  old := os.read_file('ex1.txt') or { panic(err) }
  new := os.read_file('ex/ex1.txt') or { panic(err) }
  assert old == new
  os.mkdir('ex/ex2') or { panic(err) }
  os.write_file('ex2.txt', 'great!')
  os.copy_all('ex2.txt', 'ex/ex2', false) or { panic(err) }
  old2 := os.read_file('ex2.txt') or { panic(err) }
  new2 := os.read_file('ex/ex2/ex2.txt') or { panic(err) }
  assert old2 == new2
  //recurring on dir -> local dir
  os.copy_all('ex', './', true) or { panic(err) }
}

fn test_tmpdir(){
	t := os.tmpdir()
	assert t.len > 0
	assert os.is_dir(t)

	tfile := t + filepath.separator + 'tmpfile.txt'

	os.remove(tfile) // just in case

	tfile_content := 'this is a temporary file'
	os.write_file(tfile, tfile_content)

	tfile_content_read := os.read_file(tfile) or { panic(err) }
	assert tfile_content_read == tfile_content

	os.remove(tfile)
}


fn test_make_symlink_check_is_link_and_remove_symlink() {
   $if windows {
       // TODO
       assert true
       return
   }

   folder  := 'tfolder'
   symlink := 'tsymlink'

   os.remove(symlink)
   os.remove(folder)

   os.mkdir(folder) or { panic(err) }
   folder_contents := os.ls(folder) or { panic(err) }
   assert folder_contents.len == 0

   os.system('ln -s $folder $symlink')
   assert os.is_link(symlink) == true

   os.remove(symlink)
   os.remove(folder)

   folder_exists := os.is_dir(folder)
   assert folder_exists == false

   symlink_exists := os.is_link(symlink)
   assert symlink_exists == false
}

//fn test_fork() {
//  pid := os.fork()
//  if pid == 0 {
//    println('Child')
//  }
//  else {
//    println('Parent')
//  }
//}

//fn test_wait() {
//  pid := os.fork()
//  if pid == 0 {
//    println('Child')
//    exit(0)
//  }
//  else {
//    cpid := os.wait()
//    println('Parent')
//    println(cpid)
//  }
//}

fn test_symlink() {
  $if windows { return }
  os.mkdir('symlink') or { panic(err) }
  os.symlink('symlink', 'symlink2') or { panic(err) }
  assert os.is_exist('symlink2')

  // cleanup
  os.remove('symlink')
  os.remove('symlink2')
}

fn test_is_executable_writable_readable() {
  file_name := os.tmpdir() + filepath.separator + 'rwxfile.exe'

  mut f := os.create(file_name) or {
    eprintln('failed to create file $file_name')
    return
  }
  f.close()

  $if !windows {
    os.chmod(file_name, 0o600) // mark as readable && writable, but NOT executable
    assert os.is_writable(file_name)
    assert os.is_readable(file_name)
    assert !os.is_executable(file_name)
    os.chmod(file_name, 0o700) // mark as executable too
    assert os.is_executable(file_name)
  } $else {
    assert os.is_writable(file_name)
    assert os.is_readable(file_name)
    assert os.is_executable(file_name)
  }

  // We finally delete the test file.
  os.remove(file_name)
}

// this function is called by both test_aaa_setup & test_zzz_cleanup
// it ensures that os tests do not polute the filesystem with leftover
// files so that they can be run several times in a row.
fn cleanup_leftovers() {
	// possible leftovers from test_cp
	os.remove('cp_example.txt')
	os.remove('cp_new_example.txt')

	// possible leftovers from test_cp_r
	os.remove_all('ex')
	os.remove_all('ex2')
	os.remove('ex1.txt')
	os.remove('ex2.txt')
}
