import aiohttp
import asyncio
import random
import logging
import sys
import os
from datetime import datetime
from typing import List, Dict, Optional

# Logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('gaia_bot.log')
    ]
)
logger = logging.getLogger(__name__)

class GaiaBot:
    def __init__(self):
        """Bot initialization."""
        # Check for required environment variables
        self.node_id = os.getenv("NODE_ID")
        if not self.node_id:
            logger.error("Error: NODE_ID not specified in environment variables!")
            sys.exit(1)

        # Configure URL and headers
        self.url = f"https://{self.node_id}.gaia.domains/v1/chat/completions"
        self.headers = {
            "accept": "application/json",
            "Content-Type": "application/json"
        }

        # Load additional settings from environment variables
        self.retry_count = int(os.getenv("RETRY_COUNT", "3"))
        self.retry_delay = int(os.getenv("RETRY_DELAY", "5"))
        self.timeout = int(os.getenv("TIMEOUT", "60"))

        # Initialize variables
        self.roles: List[str] = []
        self.phrases: List[str] = []
        self.session: Optional[aiohttp.ClientSession] = None

    async def initialize(self) -> None:
        """Initialize the bot and load required data."""
        try:
            self.roles = self.load_from_file("roles.txt")
            self.phrases = self.load_from_file("phrases.txt")
            self.session = aiohttp.ClientSession()
            logger.info("Bot initialized successfully")
        except Exception as e:
            logger.error(f"Initialization error: {e}")
            sys.exit(1)

    @staticmethod
    def load_from_file(file_name: str) -> List[str]:
        """Load data from a file with error handling."""
        try:
            with open(file_name, "r") as file:
                data = [line.strip() for line in file.readlines() if line.strip()]
                if not data:
                    raise ValueError(f"File {file_name} is empty")
                return data
        except FileNotFoundError:
            logger.error(f"Error: File {file_name} not found!")
            sys.exit(1)

    def generate_message(self) -> List[Dict[str, str]]:
        """Generate messages for sending."""
        user_message = {
            "role": "user",
            "content": random.choice(self.phrases)
        }
        other_message = {
            "role": random.choice([r for r in self.roles if r != "user"]),
            "content": random.choice(self.phrases)
        }
        return [user_message, other_message]

    async def send_request(self, messages: List[Dict[str, str]]) -> None:
        """Send API request with error handling and retries."""
        for attempt in range(self.retry_count):
            try:
                async with self.session.post(
                    self.url,
                    json={"messages": messages},
                    headers=self.headers,
                    timeout=self.timeout
                ) as response:
                    if response.status == 200:
                        result = await response.json()
                        self.log_success(messages[0]["content"], result)
                        return
                    else:
                        logger.warning(f"Attempt {attempt + 1}/{self.retry_count}: Status {response.status}")
                        
            except asyncio.TimeoutError:
                logger.warning(f"Attempt {attempt + 1}/{self.retry_count}: Timeout")
            except Exception as e:
                logger.error(f"Attempt {attempt + 1}/{self.retry_count}: Error: {e}")
            
            if attempt < self.retry_count - 1:
                await asyncio.sleep(self.retry_delay)

    def log_success(self, question: str, result: Dict) -> None:
        """Log a successful response."""
        response = result["choices"][0]["message"]["content"]
        logger.info(f"Question: {question}")
        logger.info(f"Answer: {response}")
        logger.info("=" * 50)

    async def run(self) -> None:
        """Main bot loop."""
        await self.initialize()
        logger.info("Bot is running and ready")
        
        try:
            while True:
                messages = self.generate_message()
                await self.send_request(messages)
                await asyncio.sleep(1)
        except KeyboardInterrupt:
            logger.info("Bot stopped by user")
        finally:
            if self.session:
                await self.session.close()

if __name__ == "__main__":
    bot = GaiaBot()
    asyncio.run(bot.run())
