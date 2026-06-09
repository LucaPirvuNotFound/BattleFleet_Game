import sys
import os

# Adaugă directorul părinte (rădăcina proiectului) în sys.path
# pentru a permite importuri absolute de tip 'from database.models...'
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))