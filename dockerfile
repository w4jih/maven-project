# ---- Build stage (si tu veux builder dans Docker) ----
# FROM maven:3.9-eclipse-temurin-21 AS build
# WORKDIR /app
# COPY . .
# RUN mvn -B -DskipTests clean package

# ---- Runtime stage ----
FROM eclipse-temurin:21-jre
WORKDIR /app
# Si tu as déjà le JAR via Jenkins (Artifacts), on le copie dans l'image :
ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
