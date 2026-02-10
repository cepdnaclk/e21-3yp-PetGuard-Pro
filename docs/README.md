---
layout: home
permalink: index.html

repository-name: e21-3yp-Smart-Dog-Collar
title: PetGuard Pro
---

# PetGuard Pro  
**Smart Pet Collar for Real-Time Tracking, Geo-fencing & Health Monitoring**

---

## Team
- **E/21/106** – Bingusari Dissanayaka  
- **E/21/137** – Chandur Fernando  
- **E/21/350** – Prashan Samarawickrama  
- **E/21/428** – Savin Weerasooriya  

<!-- Image of the final hardware / system architecture should be added here -->
<!-- Example: ![System Architecture](./images/system-architecture.png) -->

---

#### Table of Contents
1. [Introduction](#introduction)
2. [Solution Architecture](#solution-architecture)
3. [Hardware & Software Designs](#hardware--software-designs)
4. [Testing](#testing)
5. [Detailed Budget](#detailed-budget)
6. [Conclusion](#conclusion)
7. [Links](#links)

---

## Introduction

Pet owners face major challenges in ensuring the safety and health of their pets due to the lack of real-time visibility and delayed response to emergencies. Pets cannot communicate health issues or dangerous situations, making timely intervention difficult.

**PetGuard Pro** addresses this problem by providing an IoT-based smart pet collar combined with a mobile application and a cloud backend. The system enables real-time location tracking, geo-fencing alerts, health monitoring, and instant notifications to ensure proactive and reliable pet care.

---

## Solution Architecture

PetGuard Pro follows a **device–cloud–mobile architecture**:

- **Smart Pet Collar** collects location, activity, and health data using onboard sensors.
- **Cloud Backend (AWS)** securely receives, processes, and stores data while handling alerts and scalability.
- **Mobile Application (Flutter)** allows pet owners to monitor their pets in real time and receive notifications.

Communication between the collar and cloud is handled using **MQTT**, while secure **HTTPS** APIs serve the mobile application.

---

## Hardware & Software Designs

### Hardware Design (Pet Collar Unit)
- **Microcontroller:** ESP32-WROOM-32  
- **Positioning:** NEO-8M GPS  
- **Connectivity:** SIM800L GSM/GPRS (2G)  
- **Sensors:**
  - Temperature Sensor – MLX90614  
  - Heart Rate Sensor – MAX30102  
  - IMU – MPU6050  
- **Power System:**  
  - 1500 mAh 3.7V Li-Po Battery  
  - USB-C charging  

### Software Design

#### Mobile Application
- **Framework:** Flutter  
- **Features:**  
  - Live GPS tracking  
  - Geo-fencing configuration  
  - Health and activity visualization  
  - Alert notifications and history logs  

#### Cloud Backend
- **Platform:** AWS  
- **Services Used:**  
  - AWS IoT Core (MQTT communication)  
  - API Gateway & Lambda (application logic)  
  - DynamoDB & S3 (data storage)  
  - Cognito (authentication)  
  - SNS (notifications & alerts)  
  - CloudWatch (monitoring)  

---

## Testing

Testing was conducted at both **hardware** and **software** levels:

- Sensor accuracy and reliability testing  
- GPS tracking and geo-fence breach detection  
- GSM connectivity and offline caching validation  
- Cloud message throughput and alert latency testing  
- Mobile app UI, API integration, and notification testing  

Results confirmed stable performance under normal and limited-connectivity conditions.

---

## Detailed Budget

| Item                              | Quantity | Unit Cost (LKR) | Total (LKR) |
|----------------------------------|:--------:|:---------------:|------------:|
| ESP32 MCU                        | 1        | 1500            | 1500        |
| GPS Module (NEO-8M)              | 1        | 3000            | 3000        |
| GSM Module (SIM800L)             | 1        | 2000            | 2000        |
| Health Sensors (PPG, IMU, Temp)  | 1 set    | 3300            | 3300        |
| Battery & Charging Circuit       | 1        | 2200            | 2200        |
| Buck Converter                   | 1        | 1000            | 1000        |
| LEDs & Buzzer                    | 1 set    | 150             | 150         |
| PCB, Wiring & Connectors         | 1 set    | 1000            | 1000        |
| Enclosure                        | 1        | 800             | 800         |
| SIM Card                         | 1        | 500             | 500         |
| **Total**                        |          |                 | **15,450**  |

---

## Conclusion

PetGuard Pro successfully demonstrates a low-cost, scalable, and reliable smart pet monitoring system. The project integrates embedded hardware, cloud computing, and mobile technologies to deliver real-time safety and health insights. Future work includes improving battery life, enhancing analytics, and preparing the system for commercial deployment.

---

## Links

- [Project Repository](https://github.com/cepdnaclk/{{ page.repository-name }}){:target="_blank"}
- [Project Page](https://cepdnaclk.github.io/{{ page.repository-name }}){:target="_blank"}
- [Department of Computer Engineering](http://www.ce.pdn.ac.lk/)
- [University of Peradeniya](https://eng.pdn.ac.lk/)

