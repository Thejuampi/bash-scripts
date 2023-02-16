import os
import zipfile

def check_jar_conflicts(jar_path, max_conflicts=3):
    class_cache = {}
    jar_files = [os.path.join(jar_path, f) for f in os.listdir(jar_path) if f.endswith('.jar')]

    # Extract the list of class files from all JAR files
    class_map = {}
    for jar_file in jar_files:
        with zipfile.ZipFile(jar_file, 'r') as z:
            for class_file in z.namelist():
                if not class_file.endswith('.class'):
                    continue
                if class_file.startswith('META-INF/versions/') or class_file == 'module-info.class':
                    continue
                class_name = os.path.basename(class_file)[:-6]
                if class_name in class_map:
                    if jar_file != class_map[class_name]:
                        print(f"Class {class_name} in JAR {jar_file} conflicts with class in JAR {class_map[class_name]}")
                    continue
                class_map[class_name] = jar_file

    # Check for conflicts between class files
    for class_name, jar_name in class_map.items():
        for other_class_name, other_jar_name in class_cache.items():
            if class_name != other_class_name and jar_name != other_jar_name and os.path.basename(class_name) == os.path.basename(other_class_name):
                print(f"Class {class_name} in JAR {jar_name} conflicts with class in JAR {other_jar_name}")
        class_cache[class_name] = jar_name
