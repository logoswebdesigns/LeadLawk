#!/usr/bin/env python3
import httpx
import asyncio

async def check_job():
    client = httpx.AsyncClient()
    try:
        response = await client.get("http://localhost:8000/jobs/bc790684-260e-4268-879e-85e388c662d5")
        if response.status_code == 200:
            job = response.json()
            print(f"Status: {job.get('status')}")
            print(f"Progress: {job.get('processed', 0)}/{job.get('total', 0)}")
            print(f"Message: {job.get('message', '')}")
        else:
            print(f"Error: {response.status_code}")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        await client.aclose()

asyncio.run(check_job())