import os
import shutil
import tempfile
import unittest

from jar_conflicts import check_jar_conflicts


class TestJarConflicts(unittest.TestCase):

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.jar_path = os.path.join(self.temp_dir, 'jars')
        os.makedirs(self.jar_path)

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    def create_jar(self, name, classes):
        jar_file = os.path.join(self.jar_path, name)
        with zipfile.ZipFile(jar_file, 'w') as z:
            for class_file in classes:
                z.writestr(class_file, 'contents')
        return jar_file

    def test_no_conflicts(self):
        self.create_jar('foo.jar', ['com/example/Foo.class'])
        self.create_jar('bar.jar', ['com/example/Bar.class'])
        check_jar_conflicts(self.jar_path)

    def test_one_conflict(self):
        self.create_jar('foo.jar', ['com/example/Foo.class', 'com/example/Bar.class'])
        self.create_jar('bar.jar', ['com/example/Bar.class'])
        with self.assertLogs() as log:
            check_jar_conflicts(self.jar_path)
            self.assertIn('Class Bar in JAR bar.jar conflicts with class in JAR foo.jar', log.output)

    def test_multiple_conflicts(self):
        self.create_jar('foo.jar', ['com/example/Foo.class', 'com/example/Bar.class', 'com/example/Baz.class'])
        self.create_jar('bar.jar', ['com/example/Bar.class', 'com/example/Baz.class'])
        self.create_jar('baz.jar', ['com/example/Baz.class', 'com/example/Qux.class'])
        with self.assertLogs() as log:
            check_jar_conflicts(self.jar_path)
            self.assertIn('Class Bar in JAR bar.jar conflicts with class in JAR foo.jar', log.output)
            self.assertIn('Class Baz in JAR baz.jar conflicts with class in JAR bar.jar', log.output)
            self.assertIn('Class Baz in JAR baz.jar conflicts with class in JAR foo.jar', log.output)

    def test_duplicate_class_files(self):
        self.create_jar('foo.jar', ['com/example/Foo.class', 'com/example/Foo.class'])
        with self.assertLogs() as log:
            check_jar_conflicts(self.jar_path)
            self.assertIn('Duplicate class file found:', log.output[0])

    def test_java_9_files(self):
        self.create_jar('foo.jar', ['com/example/Foo.class', 'META-INF/versions/9/com/example/Foo.class', 'module-info.class'])
        self.create_jar('bar.jar', ['com/example/Bar.class'])
        check_jar_conflicts(self.jar_path)

if __name__ == '__main__':
    unittest.main()
