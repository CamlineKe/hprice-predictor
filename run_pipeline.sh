#!/bin/bash

# ============================================================================
# From Data to Model - Bash Automation Script
# Author: Gourav Shah | School of DevOps
# Description: Automates data processing, feature engineering, and model training
# ============================================================================

# ------------------------------- CONFIG -------------------------------------

PROJECT_ROOT="hprice-predictor"
INPUT_RAW="data/raw/house_data.csv"
CLEANED_DATA="data/processed/cleaned_house_data.csv"
FEATURED_DATA="data/processed/featured_house_data.csv"
PREPROCESSOR_PATH="models/trained/preprocessor.pkl"
MODEL_CONFIG="configs/model_config.yaml"
MODELS_DIR="models"
MLFLOW_URI_DEFAULT="http://localhost:5555"
MLFLOW_URI="$MLFLOW_URI_DEFAULT"

# ----------------------------------------------------------------------------

# --------------------------- Helper Functions -------------------------------

show_help() {
    echo "Usage: ./run_pipeline.sh [-m <mlflow_uri>] [-h]"
    echo ""
    echo "Options:"
    echo "  -m, --mlflow-uri   Set custom MLflow Tracking URI (default: $MLFLOW_URI_DEFAULT)"
    echo "  -h, --help         Show this help message and exit"
    echo ""
    echo "Description:"
    echo "Automates data preprocessing, feature engineering, and model training."
}

check_dependencies() {
    command -v python >/dev/null 2>&1 || { echo "❌ Python is not installed. Aborting."; exit 1; }
    command -v curl >/dev/null 2>&1 || { echo "❌ curl is required. Please install it."; exit 1; }
}

validate_file() {
    if [[ ! -f "$1" ]]; then
        echo "❌ File not found: $1"
        exit 1
    fi
}

validate_or_download_config() {
    if [[ ! -f "$MODEL_CONFIG" ]]; then
        echo "⚠️  Config file not found. Downloading sample config..."
        curl -sSL -o "$MODEL_CONFIG" \
          "https://gist.githubusercontent.com/initcron/702de323bab9a3b85ee3cde295d06d49/raw/fcf5e2bf6d3dc6739d2456a556a14ef68e929d75/model_config.json"
        echo "✅ Config downloaded to $MODEL_CONFIG"
    fi
}

validate_mlflow_running() {
    echo "🔍 Checking MLflow Tracking URI at $MLFLOW_URI..."
    if ! curl --silent --fail "$MLFLOW_URI" > /dev/null; then
        echo "❌ MLflow Tracking Server is not reachable at $MLFLOW_URI"
        echo "➡️  Please start MLflow with: mlflow ui --port 5555"
        exit 1
    fi
    echo "✅ MLflow is up and running."
}

run_data_processing() {
    echo "📦 Running data preprocessing..."
    python src/data/run_processing.py --input "$INPUT_RAW" --output "$CLEANED_DATA"
    validate_file "$CLEANED_DATA"
    echo "✅ Cleaned data available at $CLEANED_DATA"
}

run_feature_engineering() {
    echo "🔧 Running feature engineering..."
    python src/features/engineer.py --input "$CLEANED_DATA" --output "$FEATURED_DATA" --preprocessor "$PREPROCESSOR_PATH"
    validate_file "$FEATURED_DATA"
    validate_file "$PREPROCESSOR_PATH"
    echo "✅ Features generated at $FEATURED_DATA"
    echo "✅ Preprocessor saved at $PREPROCESSOR_PATH"
}

run_model_training() {
    validate_or_download_config
    validate_mlflow_running
    echo "🧠 Training model with config: $MODEL_CONFIG"
    python src/models/train_model.py \
        --config "$MODEL_CONFIG" \
        --data "$FEATURED_DATA" \
        --models-dir "$MODELS_DIR" \
        --mlflow-tracking-uri "$MLFLOW_URI"
    
    validate_file "$MODELS_DIR/trained/house_price_model.pkl"
    echo "✅ Model trained and saved to $MODELS_DIR/trained/house_price_model.pkl"
    echo "🔍 Track experiments at $MLFLOW_URI"
}

# ------------------------------- Main ---------------------------------------

main() {
    check_dependencies

    # Ensure we are in the project root directory
    if [[ ! -d "$PROJECT_ROOT" ]]; then
        echo "❌ '$PROJECT_ROOT' directory not found. Please run this script from the parent directory of the project."
        exit 1
    fi
    cd "$PROJECT_ROOT" || exit 1

    run_data_processing
    run_feature_engineering
    run_model_training
}

# --------------------------- Command Line Options ---------------------------

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -m|--mlflow-uri)
            MLFLOW_URI="$2"
            shift 2
            ;;
        *)
            echo "❌ Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ------------------------------ Execute Script ------------------------------

main
