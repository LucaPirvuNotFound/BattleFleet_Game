import sys
import os

# Adaugă directorul părinte (cel care conține folderul 'database') în sys.path
# Astfel, Python va trata 'database' ca pe un pachet importabil
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))