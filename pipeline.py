import mlflow
from mlflow import MlflowClient
import mlflow.sklearn
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score

# Apuntar al servidor en EC2
mlflow.set_tracking_uri("http://34.230.71.222:5000")
mlflow.set_experiment("modelo_iris")


with mlflow.start_run():
    # 1. Datos
    iris = load_iris()
    X_train, X_test, y_train, y_test = train_test_split(
        iris.data, iris.target, test_size=0.2, random_state=42
    )

    # 2. Hiperparámetros
    params = {"n_estimators": 100, "max_depth": 5, "random_state": 42}
    mlflow.log_params(params)

    # 3. Entrenamiento
    clf = RandomForestClassifier(**params)
    clf.fit(X_train, y_train)

    # 4. Evaluación
    preds = clf.predict(X_test)
    acc = accuracy_score(y_test, preds)
    mlflow.log_metric("accuracy", acc)

    # 5. Guardar el modelo en el Tracking Server
    mlflow.sklearn.log_model(clf, artifact_path="random_forest_model")

    print(f"Ejecución completada con Accuracy: {acc:.4f}")