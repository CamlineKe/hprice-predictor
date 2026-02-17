## 🧪 Project Spec – Simulate a Production-Grade ML System with Docker Compose

## 🎯 Project Goal

As an MLOps or AI/ML Engineer on the **AI Platform Engineering team**, your mission is to simulate a real-world ML application environment by automating its deployment using **Docker Compose**.

You will create a local dev/test setup that combines:

* ML model training and tracking (with MLflow)

* Model serving (with FastAPI)

* User interaction (with Streamlit)

This kind of environment is used by real teams to **test integration, debug workflows, and enable reproducibility** — before handing it off to production infrastructure like Kubernetes.

---

## ⚙️ What We're Automating

In a non-Compose setup, you'd be spinning up each component manually using long `docker run` commands. Here's what that looks like:

### 🔹 MLflow Tracking Server

```
docker run -d --name mlflow -p 5555:5000 \
  ghcr.io/mlflow/mlflow:latest \
  mlflow server --host 0.0.0.0
```

### 🔹 FastAPI Inference Server

```
docker build -t fastapi-app .
docker run -d --name fastapi -p 8000:8000 fastapi-app
```

### 🔹 Streamlit Frontend

```
docker build -t streamlit-app ./streamlit_app
docker run -d --name streamlit -p 8501:8501 \
  --env API_URL=http://fastapi:8000 \
  streamlit-app
```

Running and linking these services manually is tedious, error-prone, and non-reproducible.

---

## 🐳 What You'll Do Instead

You'll use **Docker Compose** to automate all of the above by writing a single `docker-compose.yml` file. This will:

* Build and launch all three services

* Set up internal networking so services can find each other by name (e.g., `http://fastapi:8000`)

* Automatically manage service dependencies

* Enable consistent and reproducible environments across your team

---

## 🏗️ System Architecture

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│   Streamlit     │─────▶│    FastAPI      │─────▶│     MLflow      │
│   (Frontend)    │      │   (Model API)   │      │   (Tracking)    │
│    Port 8501    │      │    Port 8000    │      │    Port 5555    │
│  API_URL env var│      │  Loads: model   │      │  (separate      │
│                 │      │   .pkl,         │      │   compose or    │
│                 │      │  preprocessor   │      │   included)     │
└─────────────────┘      └─────────────────┘      └─────────────────┘
        │                         │
        │                         │
        └─────────────────────────┘
              (Experiment logging)
```

**Data Flow:**
1. **User** interacts with **Streamlit** (Browser → `localhost:8501`)
2. **Streamlit** calls **FastAPI** via internal DNS (`http://fastapi:8000`)
3. **FastAPI** loads `model.pkl` + `preprocessor.pkl` and returns predictions
4. Training pipeline logs experiments to **MLflow** (`localhost:5555`)

---

## 🧱 Stack Overview

| Service | Build Context/Image | Port | Purpose | Depends On |
|---------|-------------------|------|---------|------------|
| `mlflow` | `ghcr.io/mlflow/mlflow:latest` | 5555 | Experiment tracking & model registry | - |
| `fastapi` | `.` (uses root `Dockerfile`) | 8000 | REST API for model inference | mlflow |
| `streamlit` | `./streamlit_app` (Dockerfile) | 8501 | Web UI for house price predictions | fastapi |

**Key Ports:**
- **MLflow:** `5555` → http://localhost:5555
- **FastAPI:** `8000` → http://localhost:8000/docs (Swagger UI)
- **Streamlit:** `8501` → http://localhost:8501

---

## 📂 Project Structure

```
house-price-predictor/
├── docker-compose.yaml           # Main orchestration file (you create this)
├── compose.yaml                  # Alternative modern naming
├── run_pipeline.sh               # Training script: clean → features → train → MLflow
├── run_pipeline.py               # Python equivalent of pipeline
├── Dockerfile                    # FastAPI service definition
├── requirements.txt              # Python dependencies
├── mlflow/                       # Optional: separate MLflow compose
│   └── compose.yaml
├── src/
│   ├── data/
│   │   └── data_processing.py    # Raw → Clean
│   ├── features/
│   │   └── feature_engineering.py # Clean → Features
│   ├── models/
│   │   └── train_model.py        # Train + log to MLflow
│   └── api/
│       ├── main.py               # FastAPI endpoints (/predict, /batch_predict)
│       └── inference.py          # Model loading & prediction logic
├── streamlit_app/
│   ├── Dockerfile                # Streamlit service definition
│   ├── app.py                    # Streamlit UI (reads API_URL env var)
│   └── requirements.txt          # Frontend dependencies
├── models/                       # Generated artifacts (gitignored)
│   ├── model.pkl                 # Trained model
│   └── preprocessor.pkl          # Data transformation pipeline
└── data/
    ├── raw/                      # Original synthetic data
    ├── cleaned/                  # Processed data (generated)
    └── features/                 # Engineered features (generated)
```

---

## 🔄 Workflow

### Step 1: Generate Model Artifacts

Run the provided training script **from the parent directory**:

```
cd ..
bash house-price-predictor/run_pipeline.sh
```

This will:

* **Clean raw data:** `data/raw/` → `data/cleaned/`

* **Engineer features:** `data/cleaned/` → `data/features/`

* **Train a model and preprocessor:** Trains scikit-learn model, logs to MLflow

* **Log the run to MLflow:** Experiment `house-price-model` with metrics (R² ~98%, MAE ~17,892) and parameters

* **Save model files under `models/`:** `model.pkl` and `preprocessor.pkl`

**Prerequisites:**
- MLflow running (see Step 2)
- Python 3.11+ virtual environment: `uv venv --python 3.11`
- Dependencies installed: `uv pip install -r requirements.txt`

---

### Step 2: Launch MLflow

**Option A: Manual (for understanding)**
```
docker run -d --name mlflow -p 5555:5000 \
  ghcr.io/mlflow/mlflow:latest \
  mlflow server --host 0.0.0.0
```

**Option B: Docker Compose (recommended)**
Create `mlflow/compose.yaml`:
```
services:
  mlflow:
    image: ghcr.io/mlflow/mlflow:latest
    ports:
      - "5555:5000"
    command: mlflow server --host 0.0.0.0
```

Launch: `cd mlflow && docker compose up -d`

---

### Step 3: Create Docker Compose File

Write a `docker-compose.yml` that:

* Builds the FastAPI and Streamlit images from the existing Dockerfiles

* Uses the public MLflow image

* Maps the appropriate ports: `8000:8000` (FastAPI), `8501:8501` (Streamlit), `5555:5000` (MLflow)

* Connects the services using internal DNS (`fastapi`, `mlflow`) — **Critical:** Use service names as hostnames, not `localhost`

* Passes `API_URL=http://fastapi:8000` as an environment variable to the Streamlit app

**Service Discovery Fix:**
| Context | Wrong | Correct |
|---------|-------|---------|
| Streamlit container | `http://localhost:8000` | `http://fastapi:8000` |
| Browser (your laptop) | - | `http://localhost:8000` |

**Why?** Each container has its own `localhost`. Docker Compose creates internal DNS where service names resolve to container IPs.

---

### Step 4: Build & Deploy

```
# Build all images (parallel execution)
docker compose build

# Launch full stack
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

**Idempotent Deployment:** Run `docker compose up -d` multiple times — it only recreates containers when config changes.

---

### Step 5: Cleanup

```
# Stop application stack (preserve images)
docker compose down

# Stop MLflow stack
cd mlflow && docker compose down

# Complete cleanup (use with caution)
docker system prune -a
```

---

## ✅ Validation Checklist

| Milestone | Status |
|-----------|--------|
| `run_pipeline.sh` runs successfully and generates artifacts | [ ] |
| MLflow UI accessible at http://localhost:5555 | [ ] |
| FastAPI docs available at http://localhost:8000/docs | [ ] |
| Streamlit UI loads at http://localhost:8501 | [ ] |
| **Streamlit connects to FastAPI** (Critical: no "connection failed") | [ ] |
| Service discovery working (`API_URL=http://fastapi:8000` in container) | [ ] |
| All services run together via `docker-compose up` | [ ] |
| Training pipeline logged to MLflow (experiment "house-price-model") | [ ] |

---

## 🚀 Why This Matters

Using Docker Compose this way lets you:

* **Create consistent dev/test environments** — One command setup for new team members

* **Share portable ML apps with teammates** — Version-controlled, reproducible infrastructure

* **Validate service integration before scaling to Kubernetes** — Production simulation locally

* **Work more like a real AI/ML Platform Engineering team** — Multi-service orchestration, service discovery, environment automation

**Manual vs. Compose:**

| Aspect | Manual (`docker run`) | Docker Compose |
|--------|---------------------|----------------|
| **Commands** | Multiple, complex flags | Single declarative file |
| **Memory** | Remember all ports/volumes | Codified once |
| **Networking** | Manual linking (`--link`) | Automatic service discovery |
| **Scaling** | Difficult | `docker compose up --scale` |
| **Reproducibility** | Error-prone | Version-controlled, shareable |

You're not just containerizing — you're simulating production architecture in a controlled, local setup.

---

## 🎓 Learning Outcomes

After completing this project, you'll master:

* **Docker Compose syntax:** `services`, `build`, `ports`, `depends_on`, `environment`

* **Build contexts:** Understanding why FastAPI uses root `.` and Streamlit uses `./streamlit_app`

* **Container networking:** DNS resolution, service names vs. localhost

* **Environment variables:** Configuring runtime behavior without code changes

* **MLflow integration:** Experiment tracking, artifact storage, model lineage

* **Idempotent operations:** Safe, repeatable deployment commands

---

## 🔧 Troubleshooting

**Issue:** Streamlit shows "connection failed" to API
- **Fix:** Ensure `API_URL=http://fastapi:8000` (service name), not `localhost`

**Issue:** `run_pipeline.sh` fails with "directory not found"
- **Fix:** Run from parent directory: `cd .. && bash house-price-predictor/run_pipeline.sh`

**Issue:** Port already in use
- **Fix:** Change host port in compose: `"8001:8000"` (container port remains 8000)

**Issue:** MLflow not accessible
- **Fix:** Verify Docker Desktop is running: `docker version` should show Server, not just Client
