#!/bin/bash

BASE_DIR="/c/Users/akumarmishr2/Desktop/project"
PETCLINIC_REPO_URL="https://github.com/spring-projects/spring-petclinic.git"
CONFIG_FILE="$BASE_DIR/config.txt"
MYSQL_ZIP_URL="https://cdn.mysql.com//Downloads/MySQL-9.0/mysql-9.0.0-winx64.zip" 
JAVA_AGENT_JAR="$BASE_DIR/java-agent/opentelemetry-javaagent.jar"

# Default profile
PROFILE="default"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --profile) PROFILE="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

if [ -d "$BASE_DIR/spring-petclinic" ]; then
    echo "Removing existing spring-petclinic directory..."
    rm -rf "$BASE_DIR/spring-petclinic"
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Configuration file not found!"
  exit 1
fi

parse_config() {
  while IFS='=' read -r key value; do
    case "$key" in
      db_username) USERNAME="$value" ;;
      db_password) PASSWORD="$value" ;;
    esac
  done < "$CONFIG_FILE"
}

parse_config

get_petclinic_app() {
  echo "Cloning the petclinic repository..."
  git clone $PETCLINIC_REPO_URL "$BASE_DIR/spring-petclinic"
}

remove_docker_files() {
  echo "Removing Docker-related files..."
  find "$BASE_DIR/spring-petclinic" -name "Dockerfile" -type f -delete
  find "$BASE_DIR/spring-petclinic" -name "docker-compose.yml" -type f -delete
}

build_app() {
  cd "$BASE_DIR/spring-petclinic"
  echo "Building the app with profile: $PROFILE..."

  if [ "$PROFILE" == "default" ]; then
    ./mvnw clean package -DskipTests
    cp target/*.jar "$BASE_DIR/outputs/petclinic-default.jar"
  elif [ "$PROFILE" == "mysql" ]; then
    ./mvnw clean package -DskipTests -Dspring.datasource.url=jdbc:mysql://localhost:3306/petclinic -Dspring.datasource.username=$USERNAME -Dspring.datasource.password=$PASSWORD
    cp target/*.jar "$BASE_DIR/outputs/petclinic-mysql.jar"
  else
    echo "Invalid profile specified!"
    exit 1
  fi
  cd "$BASE_DIR"
}

setup_mysql() {
  MYSQL_ZIP="$BASE_DIR/required_files/mysql.zip"

  if [ ! -f "$MYSQL_ZIP" ]; then
    echo "Downloading MySQL binary..."
    curl -L $MYSQL_ZIP_URL -o "$MYSQL_ZIP"
  else
    echo "MySQL binary already downloaded."
  fi

  echo "Unzipping MySQL binary..."
  unzip -o $MYSQL_ZIP -d "$BASE_DIR/mysql/"
}

run_app() {
  echo "Running the app..."
  if [ "$PROFILE" == "default" ]; then
    java -javaagent:$JAVA_AGENT_JAR -jar $BASE_DIR/outputs/petclinic-default.jar
  elif [ "$PROFILE" == "mysql" ]; then
    java -javaagent:$JAVA_AGENT_JAR -jar $BASE_DIR/outputs/petclinic-mysql.jar
  else
    echo "Invalid profile specified!"
    exit 1
  fi
}

echo "Starting script execution..."
cp -r "$BASE_DIR/required_files/"* "$BASE_DIR/backups/"
get_petclinic_app
remove_docker_files
build_app
setup_mysql
run_app
