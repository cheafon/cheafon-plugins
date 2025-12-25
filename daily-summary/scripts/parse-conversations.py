#!/usr/bin/env python3
"""
parse-conversations.py - 解析 ~/.claude/projects 下当天的对话记录

输出格式：JSON，包含所有当天对话的摘要和关键内容
"""

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


def get_today_str() -> str:
    """获取今天的日期字符串 (YYYY-MM-DD)"""
    return datetime.now().strftime("%Y-%m-%d")


def parse_timestamp(ts: str) -> Optional[datetime]:
    """解析 ISO 8601 时间戳"""
    try:
        # 处理 Z 结尾的 UTC 时间
        if ts.endswith('Z'):
            ts = ts[:-1] + '+00:00'
        return datetime.fromisoformat(ts)
    except (ValueError, TypeError):
        return None


def is_today(ts: str, target_date: str) -> bool:
    """检查时间戳是否是目标日期"""
    dt = parse_timestamp(ts)
    if dt is None:
        return False
    # 转换为本地时间再比较日期
    local_dt = dt.astimezone()
    return local_dt.strftime("%Y-%m-%d") == target_date


def extract_content(message: dict) -> Optional[str]:
    """从消息中提取文本内容"""
    msg = message.get('message', {})
    content = msg.get('content', '')

    if isinstance(content, str):
        return content
    elif isinstance(content, list):
        # 处理 assistant 消息的 content 数组
        texts = []
        for item in content:
            if isinstance(item, dict):
                if item.get('type') == 'text':
                    texts.append(item.get('text', ''))
                elif item.get('type') == 'thinking':
                    # 跳过 thinking 内容，通常太长且不是最终输出
                    pass
        return '\n'.join(texts) if texts else None
    return None


def parse_jsonl_file(file_path: Path, target_date: str) -> dict:
    """解析单个 JSONL 文件，提取目标日期的对话"""
    result = {
        'file': str(file_path),
        'project': file_path.parent.name,
        'summaries': [],
        'conversations': []
    }

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue

                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue

                msg_type = record.get('type')
                timestamp = record.get('timestamp', '')

                # 只处理目标日期的记录
                if not is_today(timestamp, target_date):
                    continue

                if msg_type == 'summary':
                    # 收集 Claude 自动生成的摘要
                    summary = record.get('summary', '')
                    if summary:
                        result['summaries'].append(summary)

                elif msg_type == 'user':
                    # 提取用户消息（跳过元消息）
                    if record.get('isMeta'):
                        continue
                    content = extract_content(record)
                    if content and not content.startswith('<'):  # 跳过命令标签
                        result['conversations'].append({
                            'role': 'user',
                            'content': content[:2000],  # 限制长度
                            'timestamp': timestamp
                        })

                elif msg_type == 'assistant':
                    # 提取 assistant 回复
                    content = extract_content(record)
                    if content:
                        result['conversations'].append({
                            'role': 'assistant',
                            'content': content[:3000],  # 限制长度
                            'timestamp': timestamp
                        })

    except Exception as e:
        result['error'] = str(e)

    return result


def find_and_parse_conversations(target_date: Optional[str] = None) -> dict:
    """查找并解析所有项目的对话记录"""
    if target_date is None:
        target_date = get_today_str()

    projects_dir = Path.home() / '.claude' / 'projects'

    if not projects_dir.exists():
        return {
            'date': target_date,
            'error': f'Projects directory not found: {projects_dir}',
            'projects': []
        }

    all_results = {
        'date': target_date,
        'projects': [],
        'total_summaries': 0,
        'total_conversations': 0
    }

    # 遍历所有项目目录
    for project_dir in projects_dir.iterdir():
        if not project_dir.is_dir():
            continue

        # 查找所有 JSONL 文件
        jsonl_files = list(project_dir.glob('*.jsonl'))

        for jsonl_file in jsonl_files:
            # 快速检查：文件修改时间
            mtime = datetime.fromtimestamp(jsonl_file.stat().st_mtime)
            if mtime.strftime("%Y-%m-%d") < target_date:
                # 文件最后修改时间早于目标日期，跳过
                # 注意：这是优化，可能漏掉跨天的对话
                continue

            result = parse_jsonl_file(jsonl_file, target_date)

            # 只添加有内容的结果
            if result['summaries'] or result['conversations']:
                all_results['projects'].append(result)
                all_results['total_summaries'] += len(result['summaries'])
                all_results['total_conversations'] += len(result['conversations'])

    return all_results


def main():
    """主函数"""
    # 支持指定日期参数
    target_date = sys.argv[1] if len(sys.argv) > 1 else None

    result = find_and_parse_conversations(target_date)

    # 输出 JSON 结果
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
