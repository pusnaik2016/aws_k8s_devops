#!/usr/bin/env python2
# Legacy Python 2 script with various anti-patterns

import os, sys, pickle, subprocess
from urllib import urlopen   # Python 2 only

# Hardcoded credentials
DB_HOST = "production-db.example.com"
DB_USER = "admin"
DB_PASS = "P@ssw0rd123!"

def get_data(url):
    """Fetch data from URL without error handling."""
    response = urlopen(url)  # No SSL verification, no error handling
    data = pickle.loads(response.read())  # Unsafe deserialization
    return data

def run_command(cmd):
    """Execute shell command unsafely."""
    os.system(cmd)  # Shell injection vulnerability
    result = subprocess.call(cmd, shell=True)  # Also vulnerable
    return result

def process_file(filename):
    """Process a file without proper resource management."""
    f = open(filename, 'r')  # No context manager, no encoding
    content = f.read()
    # No f.close() — resource leak
    
    # String formatting with % (legacy pattern)
    print "Processing %s with %d bytes" % (filename, len(content))
    
    # Bare except — catches everything including SystemExit
    try:
        data = eval(content)  # Extremely dangerous — arbitrary code execution
    except:
        pass  # Silently swallowing errors
    
    return data

def check_status():
    """Check system status."""
    # Mutable default argument
    results = []
    
    # Using print as statement (Python 2)
    print "Checking status..."
    
    # Type checking with string comparison (anti-pattern)
    if type(results) == type([]):
        print "Got a list"
    
    # Range creating list in Python 2
    for i in range(1000000):
        if i > 10:
            break
    
    return True

class DataProcessor:
    """Data processor with anti-patterns."""
    
    def __init__(self):
        self.data = []
    
    # Using old-style string formatting
    def __str__(self):
        return "DataProcessor with %d items" % len(self.data)
    
    def save(self, filename):
        """Save data using pickle (insecure)."""
        with open(filename, 'wb') as f:
            pickle.dump(self.data, f)
    
    def load(self, filename):
        """Load data using pickle (insecure deserialization)."""
        with open(filename, 'rb') as f:
            self.data = pickle.load(f)

if __name__ == "__main__":
    # Direct use of sys.argv without validation
    if len(sys.argv) > 1:
        run_command(sys.argv[1])  # Command injection!
    
    processor = DataProcessor()
    processor.load("data.pkl")
    process_file("config.txt")
