#!/usr/bin/env python
# coding: utf-8

# In[6]:


from pathlib import Path


# In[8]:


#Reading files from directory path

project_path = Path.home() /"Downloads" / "sparkify-data-modeling-starter"

print("Notebook location:", project_path)
print("Files:", [item.name for item in project_path.iterdir()])


# In[10]:


#Changing the working directory

import os

os.chdir(project_path)

print("New notebook location:", Path.cwd())
print("Project files:", [item.name for item in Path.cwd().iterdir()])


# In[13]:


#Confirming the data exists 

song_path = Path("data/song_data/sample_song.json")
log_path = Path("data/log_data/sample_log.json")

print("Song file exists:", song_path.exists())
print("Log file exists:", log_path.exists())


# In[14]:


downloads_path = Path.home() / "Downloads"

[item.name
for item in downloads_path.iterdir()
if "sparkify" in item.name.lower()]


# In[16]:


# Reading every line and of code

import json

song_records = []

with song_path.open(mode="r", encoding="utf-8") as file:
    for line in file:
        song = json.loads(line)
        song_records.append(song)
        
print("Number of song records:", len(song_records))


# In[ ]:




