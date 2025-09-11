# videoGeneratingAi
plan for the MVP of your video-shortening app with prompts:
App Features (MVP)

Upload Video

Accept local video file (hour-long allowed).

Attach Prompt

Text prompt describing what highlights to extract.

Optional: separate “automatic” mode with no prompt.

Process Video

Split into scenes (PySceneDetect or similar).

Transcribe audio (Whisper GPU).

Generate embeddings for scenes/transcripts.

Match scenes with prompt (via embeddings similarity).

Extract short clips based on similarity.

Output Clips

Save clips locally (e.g., clips/ folder).

Optionally merge clips into one “highlight reel”.

2️⃣ Tech Stack

Backend / Processing: Python (GPU support)

Video Handling: FFmpeg, MoviePy

Transcription: Whisper (PyTorch + GPU)

Scene Detection: PySceneDetect

Prompt Matching: OpenAI embeddings / FAISS or local embedding model

Optional GUI: Tkinter / Streamlit / Gradio for quick MVP

3️⃣ File Structure (suggested)
video_app/
 ├─ uploads/          # uploaded raw videos
 ├─ transcripts/      # whisper transcripts
 ├─ clips/            # generated short clips
 ├─ outputs/          # optional merged highlight video
 ├─ main.py           # main processing script
 └─ requirements.txt  # dependencies

4️⃣ Workflow

Upload video → save in uploads/

Enter prompt (optional)

Process:

Scene detection → slice video into segments

Transcription → text for each segment

Prompt matching → pick segments

Clip extraction → FFmpeg/MoviePy

Show or save clips in clips/
